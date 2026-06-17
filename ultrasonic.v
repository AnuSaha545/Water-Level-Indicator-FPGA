`timescale 1ns/1ps

module ultrasonic(clk, start, trigger, echo, distance_raw, new_measure, timeout);

    input clk, start, echo;
    output trigger, new_measure, timeout;
    output reg [20:0] distance_raw = 21'd0;

    parameter CLK_MHZ = 100,
              TRIGGER_PULSE_US = 10,
              TIMEOUT_MS = 3;

    localparam COUNT_TRIGGER_PULSE = CLK_MHZ * TRIGGER_PULSE_US;
    localparam COUNT_TIMEOUT = CLK_MHZ * TIMEOUT_MS * 1000;

    reg [20:0] counter = 21'd0;

    reg [2:0] state = 3'd0;
    reg [2:0] state_next = 3'd0;

    localparam IDLE         = 3'd0,
               TRIG         = 3'd1,
               WAIT_ECHO_UP = 3'd2,
               MEASUREMENT  = 3'd3,
               MEASURE_OK   = 3'd4;

    always @(posedge clk) begin
        state <= state_next;
    end

    assign trigger = (state == TRIG);
    assign new_measure = (state == MEASURE_OK);

    wire counter_timeout;
    assign counter_timeout = (counter >= COUNT_TIMEOUT);

    assign timeout = new_measure && counter_timeout;

    wire enable_counter;
    assign enable_counter = trigger || echo;

    always @(posedge clk) begin
        if (enable_counter)
            counter <= counter + 21'd1;
        else
            counter <= 21'd0;
    end

    always @(posedge clk) begin
        if ((state == MEASUREMENT) && echo)
            distance_raw <= counter;
    end

    always @(*) begin
        state_next = state;

        case (state)

            IDLE: begin
                if (start)
                    state_next = TRIG;
            end

            TRIG: begin
                // 10 us TRIG pulse
                if (counter >= COUNT_TRIGGER_PULSE - 1)
                    state_next = WAIT_ECHO_UP;
            end

            WAIT_ECHO_UP: begin
                if (echo)
                    state_next = MEASUREMENT;
            end

            MEASUREMENT: begin
                if ((~echo) || counter_timeout)
                    state_next = MEASURE_OK;
            end

            MEASURE_OK: begin
                state_next = IDLE;
            end

            default: begin
                state_next = IDLE;
            end

        endcase
    end

endmodule