`timescale 1ns / 1ps

module tb_adder;

    // Testbench signals
    logic signed [7:0] a;
    logic signed [7:0] b;
    logic signed [7:0] expected_output;
    wire signed [7:0] out;

    // Module instantiation
    bitwise_add #(
        .P(8)
    ) adder1 (
        .a(a),
        .b(b),
        .sum(out)
    );

    // Testcases - just as an example
    parameter int NUM_TESTS = 7;
    logic signed [7:0] test_a[NUM_TESTS] = '{0, 1, 8, 124, 124, -127, -127};
    logic signed [7:0] test_b[NUM_TESTS] = '{0, 2, -8, 3, 4, -1, -2};
    logic signed [7:0] expected_outputs[NUM_TESTS] = '{0, 3, 0, 127, 127, -128, -128};

    // Run tests
    initial begin
        $dumpfile("tb_adder.vcd");
        $dumpvars(0,tb_adder);
        $monitor("a = %d  b = %d  out = %d    expected out = %d", a, b, out, expected_output);

        for (int i = 0; i < NUM_TESTS; i++) begin
            a = test_a[i];
            b = test_b[i];
            expected_output = expected_outputs[i];
            #5;
            assert(out == expected_output) else $fatal(
                1, "Test %0d failed: a=%0d, b=%0d, expected_output=%0d, got %0d",
                i, test_a[i], test_b[i], expected_outputs[i], out);
        end

        #10
        $finish;

     end
endmodule
