module LCD_CTRL(clk, reset, cmd, cmd_valid, IROM_Q, IROM_rd, IROM_A, IRAM_valid, IRAM_D, IRAM_A, busy, done);
input clk;
input reset;
input [3:0] cmd;
input cmd_valid;
input [7:0] IROM_Q;
output IROM_rd;
output [5:0] IROM_A;
output IRAM_valid;
output [7:0] IRAM_D;
output [5:0] IRAM_A;
output busy;
output done;


localparam READ = 3'd0,WRITE=3'd1,WAIT=3'd2,CMD=3'd3,WDONE=3'd4;
reg [2:0] state_cs;
reg [2:0] state_ns;
reg [5:0] counter;
reg [5:0] IROM_A,IRAM_A;
reg [7:0] IMG[63:0];
reg IROM_rd,busy,done,IRAM_valid;
reg [5:0] point;

always @(posedge clk or posedge reset ) begin
    if(reset) state_cs<=READ;
    else state_cs<=state_ns;
end
//state logic
always @(*)begin
    case(state_cs)
    READ:begin
        if(IROM_A==6'd63)  state_ns = WAIT;
        else state_ns = READ;
    end
    WAIT:begin
        if(cmd_valid && cmd == 4'd0) state_ns = WRITE;
        else if(cmd_valid) state_ns = CMD;
        else state_ns = WAIT;
    end
    CMD:state_ns = WAIT;
    WRITE:begin
        if(IRAM_A==6'd63) state_ns = WDONE;
        else state_ns = WRITE;
    end
    WDONE:begin
        state_ns = WDONE;
    end
    default: state_ns = READ;   
    endcase
end
//control signal
always @(*) begin
    case(state_cs)
    READ:begin
        IROM_rd = 1'b1;
        IRAM_valid = 1'b0;
        busy = 1'b1;
        done = 1'b0;
    end
    WAIT:begin
        IROM_rd = 1'b0;
        IRAM_valid = 1'b0;
        busy = 1'b0;
        done = 1'b0;
    end
    CMD:begin
        IROM_rd = 1'b0;
        IRAM_valid = 1'b0;
        busy = 1'b1;
        done = 1'b0;
    end
    WRITE:begin
        IROM_rd = 1'b0;
        IRAM_valid = 1'b1;
        busy = 1'b1;
        done = 1'b0;     
    end
    WDONE:begin
        IROM_rd = 1'b0;
        IRAM_valid = 1'b0;
        busy = 1'b0;
        done = 1'b1;
    end
    default:begin
        IROM_rd = 1'b1;
        IRAM_valid = 1'b0;
        busy = 1'b1;
        done = 1'b0;
    end
    endcase
end
//counter
always @(posedge clk or posedge reset) begin
    if(reset) counter<=6'd0;
    else if(state_cs==READ) counter <= counter + 6'd1;
    else counter <= 6'd0;
end
//IROM_A delay 1 clk
always @(posedge clk ) begin
    IROM_A <= counter;  
end
//IRAM_A
always @(posedge clk ) begin
    if(state_cs==WRITE)
        IRAM_A <=IRAM_A+6'd1;
    else IRAM_A <=6'd0;
end
//write
assign IRAM_D = IMG[IRAM_A];
//cmd function and Read
wire [5:0] index = point;
wire [5:0] indexA = point + 6'd1;
wire [5:0] indexB = point + 6'd9;
wire [5:0] indexC = point + 6'd8;
wire [7:0] tmp1 = IMG[index]>IMG[indexA]?IMG[index]:IMG[indexA];
wire [7:0] tmp2 = IMG[indexB]>IMG[indexC]?IMG[indexB]:IMG[indexC];
wire [7:0] tmp3 = IMG[index]<IMG[indexA]?IMG[index]:IMG[indexA];
wire [7:0] tmp4 = IMG[indexB]<IMG[indexC]?IMG[indexB]:IMG[indexC];
wire [7:0] max = tmp1>tmp2?tmp1:tmp2;
wire [7:0] min = tmp3<tmp4?tmp3:tmp4;
wire [9:0] sum = (IMG[index] + IMG[indexA]) + (IMG[indexB]+ IMG[indexC]); 
always @(posedge clk or posedge reset) begin
    if(reset)begin
        point <= 6'h1b;
    end
    else if(state_cs==CMD)begin
        case (cmd)
        4'd1:begin //shift up
            if(point>6'h7)
                point <= point - 6'd8;
            else point <=point;
        end
        4'd2:begin//shift down
            if(point<6'h30)
                point <= point + 6'd8;
            else point <=point;
        end
        4'd3:begin//shift left
            if(point==6'h0||point==6'h8||point==6'h10||point==6'h18||point==6'h20||point==6'h28||point==6'h30||point==6'h38)
                point <= point;
            else point <= point - 6'd1;
        end
        4'd4:begin//shift right
            if(point==6'h6||point==6'he||point==6'h16||point==6'h1e||point==6'h26||point==6'h2e||point==6'h36||point==6'h3e)
                point <= point;
            else point <= point + 6'd1;
        end
        4'd5:begin
            IMG[index] <= max;IMG[indexA] <= max;IMG[indexB] <= max;IMG[indexC] <= max;    
        end
        4'd6:begin
            IMG[index] <= min;IMG[indexA] <= min;IMG[indexB] <= min;IMG[indexC] <= min;  
        end
        4'd7:begin //average
            IMG[index] <= sum[9:2];
            IMG[indexA] <= sum[9:2];
            IMG[indexB] <= sum[9:2];
            IMG[indexC] <= sum[9:2];
        end
        4'd8:begin //Counterclockwise Rotation
            IMG[index] <= IMG[indexA];
            IMG[indexA] <= IMG[indexB];
            IMG[indexB] <= IMG[indexC];
            IMG[indexC] <= IMG[index];   
        end
        4'd9:begin //clockwise Rotation
            IMG[index] <= IMG[indexC];
            IMG[indexA] <= IMG[index];
            IMG[indexB] <= IMG[indexA];
            IMG[indexC] <= IMG[indexB];   
            
        end
        4'd10:begin//mirror X
            IMG[index] <= IMG[indexC];
            IMG[indexA] <= IMG[indexB];
            IMG[indexB] <= IMG[indexA];
            IMG[indexC] <= IMG[index];   
            
        end
        4'd11:begin //mirror Y
            IMG[index] <= IMG[indexA];
            IMG[indexA] <= IMG[index];
            IMG[indexB] <= IMG[indexC];
            IMG[indexC] <= IMG[indexB];          
        end
        endcase
    end 
    else if(state_cs==READ) //READ
            IMG[IROM_A] <= IROM_Q;
end
endmodule



