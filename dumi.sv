class pkt;
function void print1();
$display("hai");
xyz();
endfunction

function xyz();
$display("b");
endfunction

endclass
module top;
pkt p=new();
initial begin
p.print1();
end
endmodule 
