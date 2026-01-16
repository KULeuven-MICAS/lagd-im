package analog_format_pkg;
    // ========================================================================
    // Analog Macro Data Format Package
    // ========================================================================
    function automatic integer analog_to_signed_int(input logic [4-1:0] wbl_analog);
        logic signed [4-1:0] signed_int;
        begin
            case (wbl_analog)
                4'b1110: signed_int = -7; // 4'b1001
                4'b1100: signed_int = -6; // 4'b1010
                4'b1010: signed_int = -5; // 4'b1011
                4'b1000: signed_int = -4; // 4'b1100
                4'b0110: signed_int = -3; // 4'b1101
                4'b0100: signed_int = -2; // 4'b1110
                4'b0010: signed_int = -1; // 4'b1111
                4'b0000: signed_int =  0; // 4'b0000
                4'b0011: signed_int =  1; // 4'b0001
                4'b0101: signed_int =  2; // 4'b0010
                4'b0111: signed_int =  3; // 4'b0011
                4'b1001: signed_int =  4; // 4'b0100
                4'b1011: signed_int =  5; // 4'b0101
                4'b1101: signed_int =  6; // 4'b0110
                4'b1111: signed_int =  7; // 4'b0111
                default: signed_int = 'z; // floating for invalid codes
            endcase
            return signed_int;
        end
    endfunction
endpackage