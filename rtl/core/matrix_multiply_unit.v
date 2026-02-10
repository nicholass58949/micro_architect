// =============================================================================
// 文件名: matrix_multiply_unit.v
// 功能: 简化矩阵乘法单元 - 直接计算单次矩阵向量乘法
// 描述: 输入一行向量与权重矩阵，输出一行结果
// =============================================================================

module matrix_multiply_unit (
    clk, rst_n, start, clear, done, busy,
    input_data_0, input_data_1, input_data_2, input_data_3,
    input_data_4, input_data_5, input_data_6, input_data_7,
    input_valid,
    weight_00, weight_01, weight_02, weight_03, weight_04, weight_05, weight_06, weight_07,
    weight_10, weight_11, weight_12, weight_13, weight_14, weight_15, weight_16, weight_17,
    weight_20, weight_21, weight_22, weight_23, weight_24, weight_25, weight_26, weight_27,
    weight_30, weight_31, weight_32, weight_33, weight_34, weight_35, weight_36, weight_37,
    weight_40, weight_41, weight_42, weight_43, weight_44, weight_45, weight_46, weight_47,
    weight_50, weight_51, weight_52, weight_53, weight_54, weight_55, weight_56, weight_57,
    weight_60, weight_61, weight_62, weight_63, weight_64, weight_65, weight_66, weight_67,
    weight_70, weight_71, weight_72, weight_73, weight_74, weight_75, weight_76, weight_77,
    weight_valid,
    output_data_0, output_data_1, output_data_2, output_data_3,
    output_data_4, output_data_5, output_data_6, output_data_7,
    output_valid
);

    input clk, rst_n, start, clear, input_valid, weight_valid;
    input [15:0] input_data_0, input_data_1, input_data_2, input_data_3;
    input [15:0] input_data_4, input_data_5, input_data_6, input_data_7;
    
    input [15:0] weight_00, weight_01, weight_02, weight_03, weight_04, weight_05, weight_06, weight_07;
    input [15:0] weight_10, weight_11, weight_12, weight_13, weight_14, weight_15, weight_16, weight_17;
    input [15:0] weight_20, weight_21, weight_22, weight_23, weight_24, weight_25, weight_26, weight_27;
    input [15:0] weight_30, weight_31, weight_32, weight_33, weight_34, weight_35, weight_36, weight_37;
    input [15:0] weight_40, weight_41, weight_42, weight_43, weight_44, weight_45, weight_46, weight_47;
    input [15:0] weight_50, weight_51, weight_52, weight_53, weight_54, weight_55, weight_56, weight_57;
    input [15:0] weight_60, weight_61, weight_62, weight_63, weight_64, weight_65, weight_66, weight_67;
    input [15:0] weight_70, weight_71, weight_72, weight_73, weight_74, weight_75, weight_76, weight_77;
    
    output reg done, busy, output_valid;
    output reg [31:0] output_data_0, output_data_1, output_data_2, output_data_3;
    output reg [31:0] output_data_4, output_data_5, output_data_6, output_data_7;

    wire compute_fire;
    integer i0, i1, i2, i3, i4, i5, i6, i7;

    always @(*) begin
        i0 = input_data_0;
        i1 = input_data_1;
        i2 = input_data_2;
        i3 = input_data_3;
        i4 = input_data_4;
        i5 = input_data_5;
        i6 = input_data_6;
        i7 = input_data_7;
    end

    assign compute_fire = start && input_valid && weight_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0;
            done <= 0;
            output_valid <= 0;
            output_data_0 <= 0;
            output_data_1 <= 0;
            output_data_2 <= 0;
            output_data_3 <= 0;
            output_data_4 <= 0;
            output_data_5 <= 0;
            output_data_6 <= 0;
            output_data_7 <= 0;
        end else if (clear) begin
            busy <= 0;
            done <= 0;
            output_valid <= 0;
            output_data_0 <= 0;
            output_data_1 <= 0;
            output_data_2 <= 0;
            output_data_3 <= 0;
            output_data_4 <= 0;
            output_data_5 <= 0;
            output_data_6 <= 0;
            output_data_7 <= 0;
        end else begin
            done <= 0;
            output_valid <= 0;
            busy <= compute_fire;

            if (compute_fire) begin
                output_data_0 <= i0 * weight_00 + i1 * weight_01 + i2 * weight_02 + i3 * weight_03 + i4 * weight_04 + i5 * weight_05 + i6 * weight_06 + i7 * weight_07;
                output_data_1 <= i0 * weight_10 + i1 * weight_11 + i2 * weight_12 + i3 * weight_13 + i4 * weight_14 + i5 * weight_15 + i6 * weight_16 + i7 * weight_17;
                output_data_2 <= i0 * weight_20 + i1 * weight_21 + i2 * weight_22 + i3 * weight_23 + i4 * weight_24 + i5 * weight_25 + i6 * weight_26 + i7 * weight_27;
                output_data_3 <= i0 * weight_30 + i1 * weight_31 + i2 * weight_32 + i3 * weight_33 + i4 * weight_34 + i5 * weight_35 + i6 * weight_36 + i7 * weight_37;
                output_data_4 <= i0 * weight_40 + i1 * weight_41 + i2 * weight_42 + i3 * weight_43 + i4 * weight_44 + i5 * weight_45 + i6 * weight_46 + i7 * weight_47;
                output_data_5 <= i0 * weight_50 + i1 * weight_51 + i2 * weight_52 + i3 * weight_53 + i4 * weight_54 + i5 * weight_55 + i6 * weight_56 + i7 * weight_57;
                output_data_6 <= i0 * weight_60 + i1 * weight_61 + i2 * weight_62 + i3 * weight_63 + i4 * weight_64 + i5 * weight_65 + i6 * weight_66 + i7 * weight_67;
                output_data_7 <= i0 * weight_70 + i1 * weight_71 + i2 * weight_72 + i3 * weight_73 + i4 * weight_74 + i5 * weight_75 + i6 * weight_76 + i7 * weight_77;
                output_valid <= 1;
                done <= 1;
            end
        end
    end

endmodule
