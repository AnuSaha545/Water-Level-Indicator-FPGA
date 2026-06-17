`timescale 1ns/1ps

module lcd_i2c_level(
    input clk,
    input [1:0] level,
    output lcd_scl,
    inout lcd_sda
);

    // Try 7'h27 first. If LCD shows garbage/no text, try 7'h3F.
    localparam LCD_ADDR = 7'h27;

    // Slower I2C for stability: about 50 kHz with 100 MHz clock
    localparam I2C_DIV = 1000;

    reg scl_reg = 1'b1;
    reg sda_oe  = 1'b0;   // 1 = drive SDA low, 0 = release SDA

    assign lcd_scl = scl_reg;
    assign lcd_sda = sda_oe ? 1'b0 : 1'bz;

    // ----------------------------------------------------
    // I2C byte sender
    // ----------------------------------------------------
    reg [7:0] i2c_data = 8'd0;
    reg i2c_start = 1'b0;
    reg i2c_busy  = 1'b0;
    reg i2c_done  = 1'b0;

    reg [7:0] shift_reg = 8'd0;
    reg [3:0] bit_count = 4'd0;
    reg [15:0] div_count = 16'd0;
    reg [3:0] i2c_state = 4'd0;
    reg sending_data = 1'b0;

    localparam I_IDLE      = 4'd0,
               I_START_A   = 4'd1,
               I_START_B   = 4'd2,
               I_BIT_LOW   = 4'd3,
               I_BIT_HIGH  = 4'd4,
               I_ACK_LOW   = 4'd5,
               I_ACK_HIGH  = 4'd6,
               I_STOP_A    = 4'd7,
               I_STOP_B    = 4'd8,
               I_STOP_C    = 4'd9;

    wire tick = (div_count == I2C_DIV - 1);

    always @(posedge clk) begin
        i2c_done <= 1'b0;

        if (i2c_state == I_IDLE) begin
            div_count <= 16'd0;
        end
        else begin
            if (tick)
                div_count <= 16'd0;
            else
                div_count <= div_count + 16'd1;
        end

        if (i2c_state == I_IDLE && i2c_start) begin
            i2c_busy <= 1'b1;
            sending_data <= 1'b0;
            shift_reg <= {LCD_ADDR, 1'b0};   // Address + write bit
            bit_count <= 4'd7;
            scl_reg <= 1'b1;
            sda_oe <= 1'b0;
            i2c_state <= I_START_A;
        end
        else if (tick) begin
            case (i2c_state)

                I_START_A: begin
                    scl_reg <= 1'b1;
                    sda_oe <= 1'b1;          // SDA LOW while SCL HIGH
                    i2c_state <= I_START_B;
                end

                I_START_B: begin
                    scl_reg <= 1'b0;
                    bit_count <= 4'd7;
                    i2c_state <= I_BIT_LOW;
                end

                I_BIT_LOW: begin
                    scl_reg <= 1'b0;
                    sda_oe <= ~shift_reg[bit_count];  // 0 = drive LOW, 1 = release
                    i2c_state <= I_BIT_HIGH;
                end

                I_BIT_HIGH: begin
                    scl_reg <= 1'b1;
                    if (bit_count == 0)
                        i2c_state <= I_ACK_LOW;
                    else begin
                        bit_count <= bit_count - 1'b1;
                        i2c_state <= I_BIT_LOW;
                    end
                end

                I_ACK_LOW: begin
                    scl_reg <= 1'b0;
                    sda_oe <= 1'b0;          // Release SDA for ACK
                    i2c_state <= I_ACK_HIGH;
                end

                I_ACK_HIGH: begin
                    scl_reg <= 1'b1;

                    if (sending_data == 1'b0) begin
                        // Address completed, now send data byte
                        sending_data <= 1'b1;
                        shift_reg <= i2c_data;
                        bit_count <= 4'd7;
                        i2c_state <= I_BIT_LOW;
                    end
                    else begin
                        // Data byte completed
                        i2c_state <= I_STOP_A;
                    end
                end

                I_STOP_A: begin
                    scl_reg <= 1'b0;
                    sda_oe <= 1'b1;
                    i2c_state <= I_STOP_B;
                end

                I_STOP_B: begin
                    scl_reg <= 1'b1;
                    sda_oe <= 1'b1;
                    i2c_state <= I_STOP_C;
                end

                I_STOP_C: begin
                    scl_reg <= 1'b1;
                    sda_oe <= 1'b0;          // SDA released HIGH = STOP
                    i2c_busy <= 1'b0;
                    i2c_done <= 1'b1;
                    i2c_state <= I_IDLE;
                end

                default: begin
                    i2c_state <= I_IDLE;
                    i2c_busy <= 1'b0;
                    sda_oe <= 1'b0;
                    scl_reg <= 1'b1;
                end

            endcase
        end
    end

    // ----------------------------------------------------
    // PCF8574 to LCD byte format
    // P0 = RS, P1 = RW, P2 = EN, P3 = Backlight
    // P4-P7 = LCD D4-D7
    // ----------------------------------------------------
    function [7:0] pcf_byte;
        input [3:0] nibble;
        input rs;
        input en;
        begin
            pcf_byte = {nibble, 1'b1, en, 1'b0, rs};
        end
    endfunction

    function [7:0] line1_char;
        input [4:0] pos;
        begin
            case (pos)
                5'd0:  line1_char = "W";
                5'd1:  line1_char = "A";
                5'd2:  line1_char = "T";
                5'd3:  line1_char = "E";
                5'd4:  line1_char = "R";
                5'd5:  line1_char = " ";
                5'd6:  line1_char = "L";
                5'd7:  line1_char = "E";
                5'd8:  line1_char = "V";
                5'd9:  line1_char = "E";
                5'd10: line1_char = "L";
                5'd11: line1_char = ":";
                default: line1_char = " ";
            endcase
        end
    endfunction

    function [7:0] line2_char;
        input [1:0] lvl;
        input [4:0] pos;
        begin
            case (lvl)

                // FULL
                2'd0: begin
                    case (pos)
                        5'd0: line2_char = "F";
                        5'd1: line2_char = "U";
                        5'd2: line2_char = "L";
                        5'd3: line2_char = "L";
                        default: line2_char = " ";
                    endcase
                end

                // MEDIUM
                2'd1: begin
                    case (pos)
                        5'd0: line2_char = "M";
                        5'd1: line2_char = "E";
                        5'd2: line2_char = "D";
                        5'd3: line2_char = "I";
                        5'd4: line2_char = "U";
                        5'd5: line2_char = "M";
                        default: line2_char = " ";
                    endcase
                end

                // EMPTY
                2'd2: begin
                    case (pos)
                        5'd0: line2_char = "E";
                        5'd1: line2_char = "M";
                        5'd2: line2_char = "P";
                        5'd3: line2_char = "T";
                        5'd4: line2_char = "Y";
                        default: line2_char = " ";
                    endcase
                end

                default: line2_char = " ";
            endcase
        end
    endfunction

    // ----------------------------------------------------
    // LCD Controller FSM
    // ----------------------------------------------------
    reg [7:0] lcd_byte = 8'd0;
    reg lcd_rs = 1'b0;
    reg send_mode = 1'b0;     // 0 = send full byte, 1 = send only nibble
    reg [1:0] phase = 2'd0;

    reg [7:0] lcd_state = 8'd0;
    reg [7:0] return_state = 8'd0;
    reg [30:0] wait_count = 31'd0;
    reg [4:0] char_pos = 5'd0;

    localparam S_POWER_WAIT   = 8'd0,
               S_INIT_1       = 8'd1,
               S_INIT_2       = 8'd2,
               S_INIT_3       = 8'd3,
               S_INIT_4       = 8'd4,
               S_INIT_5       = 8'd5,
               S_INIT_6       = 8'd6,
               S_INIT_7       = 8'd7,
               S_FUNC_SET     = 8'd8,
               S_DISP_ON      = 8'd9,
               S_ENTRY        = 8'd10,
               S_CLEAR        = 8'd11,
               S_CLEAR_WAIT   = 8'd12,
               S_SET_LINE1    = 8'd13,
               S_WRITE_LINE1  = 8'd14,
               S_SET_LINE2    = 8'd15,
               S_WRITE_LINE2  = 8'd16,
               S_REFRESH_WAIT = 8'd17,
               S_SEND         = 8'd20,
               S_WAIT_DELAY   = 8'd21;

    localparam DELAY_50MS  = 31'd5000000;
    localparam DELAY_5MS   = 31'd500000;
    localparam DELAY_2MS   = 31'd200000;
    localparam DELAY_100US = 31'd10000;
    localparam DELAY_300MS = 31'd30000000;

    task start_delay;
        input [30:0] dly;
        input [7:0] next_state;
        begin
            wait_count <= dly;
            return_state <= next_state;
            lcd_state <= S_WAIT_DELAY;
        end
    endtask

    task start_send_byte;
        input [7:0] data;
        input rs;
        input [7:0] next_state;
        begin
            lcd_byte <= data;
            lcd_rs <= rs;
            send_mode <= 1'b0;
            phase <= 2'd0;
            return_state <= next_state;
            lcd_state <= S_SEND;
        end
    endtask

    task start_send_nibble;
        input [3:0] nib;
        input [7:0] next_state;
        begin
            lcd_byte <= {4'd0, nib};
            lcd_rs <= 1'b0;
            send_mode <= 1'b1;
            phase <= 2'd0;
            return_state <= next_state;
            lcd_state <= S_SEND;
        end
    endtask

    always @(posedge clk) begin
        i2c_start <= 1'b0;

        case (lcd_state)

            S_POWER_WAIT: begin
                start_delay(DELAY_50MS, S_INIT_1);
            end

            // Correct LCD 4-bit initialization sequence:
            // 0x3, 0x3, 0x3, 0x2
            S_INIT_1: begin
                start_send_nibble(4'h3, S_INIT_2);
            end

            S_INIT_2: begin
                start_delay(DELAY_5MS, S_INIT_3);
            end

            S_INIT_3: begin
                start_send_nibble(4'h3, S_INIT_4);
            end

            S_INIT_4: begin
                start_delay(DELAY_5MS, S_INIT_5);
            end

            S_INIT_5: begin
                start_send_nibble(4'h3, S_INIT_6);
            end

            S_INIT_6: begin
                start_delay(DELAY_5MS, S_INIT_7);
            end

            S_INIT_7: begin
                start_send_nibble(4'h2, S_FUNC_SET);
            end

            S_FUNC_SET: begin
                start_send_byte(8'h28, 1'b0, S_DISP_ON); // 4-bit, 2-line
            end

            S_DISP_ON: begin
                start_send_byte(8'h0C, 1'b0, S_ENTRY);   // Display ON, cursor OFF
            end

            S_ENTRY: begin
                start_send_byte(8'h06, 1'b0, S_CLEAR);   // Entry mode
            end

            S_CLEAR: begin
                start_send_byte(8'h01, 1'b0, S_CLEAR_WAIT); // Clear display
            end

            S_CLEAR_WAIT: begin
                start_delay(DELAY_2MS, S_SET_LINE1);
            end

            S_SET_LINE1: begin
                char_pos <= 5'd0;
                start_send_byte(8'h80, 1'b0, S_WRITE_LINE1);
            end

            S_WRITE_LINE1: begin
                if (char_pos < 16) begin
                    start_send_byte(line1_char(char_pos), 1'b1, S_WRITE_LINE1);
                    char_pos <= char_pos + 5'd1;
                end
                else begin
                    lcd_state <= S_SET_LINE2;
                end
            end

            S_SET_LINE2: begin
                char_pos <= 5'd0;
                start_send_byte(8'hC0, 1'b0, S_WRITE_LINE2);
            end

            S_WRITE_LINE2: begin
                if (char_pos < 16) begin
                    start_send_byte(line2_char(level, char_pos), 1'b1, S_WRITE_LINE2);
                    char_pos <= char_pos + 5'd1;
                end
                else begin
                    start_delay(DELAY_300MS, S_SET_LINE1);
                end
            end

            S_SEND: begin
                if (!i2c_busy && !i2c_start) begin
                    if (send_mode == 1'b1) begin
                        // Initialization nibble only
                        if (phase == 2'd0)
                            i2c_data <= pcf_byte(lcd_byte[3:0], lcd_rs, 1'b1);
                        else
                            i2c_data <= pcf_byte(lcd_byte[3:0], lcd_rs, 1'b0);
                    end
                    else begin
                        // Full byte in 4-bit mode
                        case (phase)
                            2'd0: i2c_data <= pcf_byte(lcd_byte[7:4], lcd_rs, 1'b1);
                            2'd1: i2c_data <= pcf_byte(lcd_byte[7:4], lcd_rs, 1'b0);
                            2'd2: i2c_data <= pcf_byte(lcd_byte[3:0], lcd_rs, 1'b1);
                            2'd3: i2c_data <= pcf_byte(lcd_byte[3:0], lcd_rs, 1'b0);
                        endcase
                    end

                    i2c_start <= 1'b1;
                end

                if (i2c_done) begin
                    if ((send_mode == 1'b1 && phase == 2'd1) ||
                        (send_mode == 1'b0 && phase == 2'd3)) begin
                        start_delay(DELAY_100US, return_state);
                    end
                    else begin
                        phase <= phase + 2'd1;
                    end
                end
            end

            S_WAIT_DELAY: begin
                if (wait_count == 0)
                    lcd_state <= return_state;
                else
                    wait_count <= wait_count - 31'd1;
            end

            default: begin
                lcd_state <= S_POWER_WAIT;
            end

        endcase
    end

endmodule