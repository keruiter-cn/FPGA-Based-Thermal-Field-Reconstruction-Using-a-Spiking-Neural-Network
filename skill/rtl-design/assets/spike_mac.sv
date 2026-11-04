`timescale 1ns/1ps
// Simplified reusable template. No pooling, bypass, CDC, or output backpressure.
module spike_mac #(
    parameter integer CHANNELS = 32,
    parameter integer WEIGHT_W = 16,
    parameter integer ACC_W = 32
)(
    input logic clk, rst_n, clear,
    input logic in_valid,
    input logic [CHANNELS-1:0] spikes,
    input logic [CHANNELS*WEIGHT_W-1:0] weights,
    input logic signed [ACC_W-1:0] bias, threshold,
    input logic fire, last,
    output logic out_valid, out_last,
    output logic signed [ACC_W-1:0] out_data
);
    localparam integer GROUPS = CHANNELS/8;
    logic signed [ACC_W-1:0] partial_comb [0:GROUPS-1];
    logic signed [ACC_W-1:0] partial_reg [0:GROUPS-1];
    logic signed [ACC_W-1:0] bias_reg, threshold_reg, accumulator;
    logic valid_reg, fire_reg, last_reg;
    logic signed [ACC_W-1:0] dot, next_value;
    integer g, lane;
    initial begin
        if (CHANNELS < 8 || CHANNELS % 8 != 0 || WEIGHT_W < 2 || ACC_W < WEIGHT_W+$clog2(CHANNELS))
            $fatal(1, "Unsupported dimensions/widths");
    end
    always_comb begin
        for (integer k=0; k<GROUPS; k=k+1) begin
            partial_comb[k] = '0;
            for (integer j=0; j<8; j=j+1)
                if (spikes[k*8+j])
                    partial_comb[k] = partial_comb[k] +
                        {{(ACC_W-WEIGHT_W){weights[(k*8+j+1)*WEIGHT_W-1]}},
                          weights[(k*8+j)*WEIGHT_W +: WEIGHT_W]};
        end
        dot = '0;
        for (integer k=0; k<GROUPS; k=k+1)
            dot = dot + partial_reg[k];
        next_value = accumulator + dot + (fire_reg ? bias_reg : {ACC_W{1'b0}});
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_reg <= 0;
            fire_reg <= 0;
            last_reg <= 0;
            bias_reg <= '0;
            threshold_reg <= '0;
            accumulator <= '0;
            out_valid <= 0;
            out_last <= 0;
            out_data <= '0;
            for (integer k=0; k<GROUPS; k=k+1) partial_reg[k] <= '0;
        end else if (clear) begin
            valid_reg <= 0;
            accumulator <= '0;
            out_valid <= 0;
            out_last <= 0;
            out_data <= '0;
        end else begin
            valid_reg <= in_valid;
            if (in_valid) begin
                for (integer k=0; k<GROUPS; k=k+1) partial_reg[k] <= partial_comb[k];
                bias_reg <= bias;
                threshold_reg <= threshold;
                fire_reg <= fire;
                last_reg <= last;
            end
            out_valid <= valid_reg && (fire_reg || last_reg);
            out_last <= valid_reg && last_reg;
            if (valid_reg) begin
                if (last_reg) begin
                    out_data <= next_value;
                    accumulator <= '0;
                end else if (fire_reg && $signed(next_value) >= $signed(threshold_reg)) begin
                    out_data <= {{(ACC_W-1){1'b0}},1'b1};
                    accumulator <= '0;
                end else begin
                    out_data <= '0;
                    accumulator <= next_value;
                end
            end
        end
    end
endmodule
