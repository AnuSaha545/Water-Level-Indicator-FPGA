`timescale 1ns/1ps

module top(CLOCK_100, TRIG, ECHO, LED, LCD_SCL, LCD_SDA);

    input        CLOCK_100;
    output       TRIG;
    input        ECHO;
    output [7:0] LED;

    output       LCD_SCL;
    inout        LCD_SDA;

    wire start, new_measure, timeout;
    wire [20:0] distance_raw;

    reg [24:0] counter_ping = 25'd0;

    localparam CLK_MHZ = 100;
    localparam PERIOD_PING_MS = 60;
    localparam COUNTER_MAX_PING = CLK_MHZ * PERIOD_PING_MS * 1000;

    // For 100 MHz clock, 1 cm distance is approximately 5800 counts
    localparam D = 5800;

    // level = 0 -> FULL
    // level = 1 -> MEDIUM
    // level = 2 -> EMPTY
    reg [1:0] level;

    ultrasonic #(
        .CLK_MHZ(100),
        .TRIGGER_PULSE_US(10),
        .TIMEOUT_MS(3)
    ) U1 (
        .clk(CLOCK_100),
        .start(start),
        .trigger(TRIG),
        .echo(ECHO),
        .distance_raw(distance_raw),
        .new_measure(new_measure),
        .timeout(timeout)
    );

    // Water level decision
    // Sensor is placed at the top of the tank.
    // Smaller distance means water level is higher.
    always @(*) begin
        if (distance_raw <= 5*D)
            level = 2'd0;       // FULL
        else if (distance_raw <= 14*D)
            level = 2'd1;       // MEDIUM
        else
            level = 2'd2;       // EMPTY
    end

    // LED indication based on distance
    // 0 to 5 cm       -> all OFF
    // more than 5 cm  -> LED[7] ON
    // more than 10 cm -> LED[7], LED[5] ON
    // more than 14 cm -> LED[7], LED[5], LED[2] ON
    // more than 18 cm -> LED[7], LED[5], LED[2], LED[0] ON

    assign LED[7] = (distance_raw > 5*D);
    assign LED[5] = (distance_raw > 10*D);
    assign LED[2] = (distance_raw > 14*D);
    assign LED[0] = (distance_raw > 18*D);

    // Unused LEDs are OFF
    assign LED[6] = 1'b0;
    assign LED[4] = 1'b0;
    assign LED[3] = 1'b0;
    assign LED[1] = 1'b0;

    // I2C LCD display module
    lcd_i2c_level LCD1 (
        .clk(CLOCK_100),
        .level(level),
        .lcd_scl(LCD_SCL),
        .lcd_sda(LCD_SDA)
    );

    // Start a new ultrasonic measurement every 60 ms
    assign start = (counter_ping == COUNTER_MAX_PING - 1);

    always @(posedge CLOCK_100) begin
        if (counter_ping == COUNTER_MAX_PING - 1)
            counter_ping <= 25'd0;
        else
            counter_ping <= counter_ping + 25'd1;
    end

endmodule