// 64项BHT与直接映射BTB分支预测器
module branch_predictor (
    input  wire        clk,
    input  wire        reset,

    input  wire [31:0] lookup_pc,
    input  wire [31:0] lookup_instr,
    output reg         predicted_taken,
    output reg  [31:0] predicted_target,
    output reg  [31:0] predicted_next_pc,

    input  wire        update_valid,
    input  wire [1:0]  update_type,
    input  wire [31:0] update_pc,
    input  wire        actual_taken,
    input  wire [31:0] actual_target
);

    localparam UPDATE_BRANCH = 2'b01;
    localparam UPDATE_JAL    = 2'b10;
    localparam UPDATE_JALR   = 2'b11;

    reg [1:0]  bht [0:63];
    reg        btb_valid [0:63];
    reg [23:0] btb_tag [0:63];
    reg [31:0] btb_target [0:63];
    integer i;

    wire [5:0]  lookup_index;
    wire [23:0] lookup_tag;
    wire        btb_hit;
    wire [31:0] jal_imm;
    wire [5:0]  update_index;
    wire [23:0] update_tag;

    assign lookup_index = lookup_pc[7:2];
    assign lookup_tag   = lookup_pc[31:8];
    assign btb_hit = btb_valid[lookup_index] &&
                     (btb_tag[lookup_index] == lookup_tag);
    assign jal_imm = {{11{lookup_instr[31]}}, lookup_instr[31],
                      lookup_instr[19:12], lookup_instr[20],
                      lookup_instr[30:21], 1'b0};
    assign update_index = update_pc[7:2];
    assign update_tag   = update_pc[31:8];

    // JAL静态预测taken，条件分支使用BHT方向和BTB目标
    always @(*) begin
        predicted_taken   = 1'b0;
        predicted_target  = lookup_pc + 32'd4;
        predicted_next_pc = lookup_pc + 32'd4;

        case (lookup_instr[6:0])
            7'b1101111: begin // JAL
                predicted_taken   = 1'b1;
                predicted_target  = lookup_pc + jal_imm;
                predicted_next_pc = lookup_pc + jal_imm;
            end
            7'b1100011: begin // Conditional Branch
                if (btb_hit && bht[lookup_index][1]) begin
                    predicted_taken   = 1'b1;
                    predicted_target  = btb_target[lookup_index];
                    predicted_next_pc = btb_target[lookup_index];
                end
            end
            7'b1100111: begin // JALR
                if (btb_hit) begin
                    predicted_taken   = 1'b1;
                    predicted_target  = btb_target[lookup_index];
                    predicted_next_pc = btb_target[lookup_index];
                end
            end
            default: begin
                predicted_taken   = 1'b0;
                predicted_target  = lookup_pc + 32'd4;
                predicted_next_pc = lookup_pc + 32'd4;
            end
        endcase
    end

    // EX阶段按真实执行结果更新BHT和BTB
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 64; i = i + 1) begin
                bht[i]        <= 2'b01;
                btb_valid[i]  <= 1'b0;
                btb_tag[i]    <= 24'b0;
                btb_target[i] <= 32'b0;
            end
        end else if (update_valid) begin
            if (update_type == UPDATE_BRANCH) begin
                if (actual_taken) begin
                    if (bht[update_index] != 2'b11)
                        bht[update_index] <= bht[update_index] + 2'b01;
                end else begin
                    if (bht[update_index] != 2'b00)
                        bht[update_index] <= bht[update_index] - 2'b01;
                end
            end

            if (actual_taken &&
                ((update_type == UPDATE_BRANCH) ||
                 (update_type == UPDATE_JAL) ||
                 (update_type == UPDATE_JALR))) begin
                btb_valid[update_index]  <= 1'b1;
                btb_tag[update_index]    <= update_tag;
                btb_target[update_index] <= actual_target;
            end
        end
    end

endmodule
