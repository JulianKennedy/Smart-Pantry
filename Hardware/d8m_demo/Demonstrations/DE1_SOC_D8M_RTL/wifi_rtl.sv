
//=======================================================
//  This code is generated by Terasic System Builder
//=======================================================

module wifi_rtl(
	input 		  logic        		CLOCK_50,

	// //////////// SEG7 //////////
	// output		logic     [6:0]		HEX0,
	// output		 logic    [6:0]		HEX1,
	// output		logic     [6:0]		HEX2,
	// output		logic     [6:0]		HEX3,
	// output		logic     [6:0]		HEX4,
	// output		logic     [6:0]		HEX5,

    input logic [7:0] data_in,
    input logic data_in_valid,

    input logic data_end,

    output logic data_accepted,

    output logic increment_table_number,

    input logic [15:0] table_number_ascii,

    input logic sendPOST,

	//////////// KEY //////////
	input 		logic		reset,

	//////////// LED //////////
	//output		logic     [9:0]		LEDR,

	//////////// SW //////////
	input 		logic     		start,

	//////////// GPIO_0, GPIO_0 connect to GPIO Default //////////
	inout 		wire    [35:0]		GPIO, 	

    output      logic             txclk,
    output      logic             rxclk
	
);
//=============================================================================
// REG/WIRE declarations
//=============================================================================



// logic        rxclk;
// logic        txclk;

//instantiate 198x8 bit registers

logic [7:0] mem [0:216];
logic [7:0] i;
logic [31:0] j;
logic [7:0] stringindex;

//finite state machine to initialize memory with ascii "print("aa")/r/n"

// wire initmemdone;

logic tx_done;
logic tx_start;
logic [7:0] tx_data;
logic tx_out;
logic tx_busy;


// logic reset;



//instantiate uart module
// uart uart0(
// 		               .reset(reset) ,     
// 		               .txclk(txclk),              
// 		               .ld_tx_data(ld_tx_data),
// 		               .tx_data(tx_data),
//                        .tx_enable(1'b1),
//                        .tx_out(GPIO[35]),
//                        .tx_empty( tx_empty),
//                        .rxclk(rxclk),
//                        .uld_rx_data(  ),
//                        .rx_data(  ),
//                        .rx_enable(1'b0),
//                        .rx_in(  ),
//                        .rx_empty(  )
		              
// 	               );		

Uart8Transmitter Uart8Transmitter0(
                    .clk(txclk) ,     
                    .en(1'b1),
                    .start(tx_start),
                    .in(tx_data),
                    .out(GPIO[35]),
                    .done(tx_done),
                    .busy(tx_busy)
            );

// input  wire       clk,   // baud rate
//     input  wire       en,
//     input  wire       start, // start of transaction
//     input  wire [7:0] in,    // data to transmit
//     output reg        out,   // tx
//     output reg        done,  // end on transaction
//     output reg        busy   // transaction is in process

BaudRateGenerator #(.CLOCK_RATE(50000000), .BAUD_RATE(115200))BaudRateGenerator0(
                       .clk(CLOCK_50) ,     
                       .rxClk(rxclk),              
                       .txClk(txclk)
                   );


enum {Rst1, SendPOSTstate, loadmem, footer, send, Waitsend, Finished, Waitnewline} current_state2;


always @(posedge txclk) begin
    if (reset || current_state2 == Rst1) begin
        if(start && data_in_valid) begin
            if(sendPOST) begin
                current_state2 <= SendPOSTstate;
                //ascii for "sendPOST1()""
                mem[0] <= 8'h73;
                mem[1] <= 8'h65;
                mem[2] <= 8'h6e;
                mem[3] <= 8'h64;
                mem[4] <= 8'h50;
                mem[5] <= 8'h4f;
                mem[6] <= 8'h53;
                mem[7] <= 8'h54;
                mem[8] <= 8'h31;
                mem[9] <= 8'h28;
                mem[10] <= 8'h29;
                mem[11] <= 8'h0d;
                mem[12] <= 8'h0a;
                stringindex <= 10;


            end else begin
                current_state2 <= loadmem;
                //ascii for " table[table_number]=" "
                mem[0] <= 8'h74;
                mem[1] <= 8'h61;
                mem[2] <= 8'h62;
                mem[3] <= 8'h6c;
                mem[4] <= 8'h65;
                mem[5] <= 8'h5b;
                mem[6] <= table_number_ascii[15:8];
                mem[7] <= table_number_ascii[7:0];
                mem[8] <= 8'h5d;
                mem[9] <= 8'h3d;
                mem[10] <= 8'h22;
                stringindex <= 11;
            end
        end else begin
            current_state2 <= Rst1;
        end
        
        i <= 0;
        
        j <= 0;

    end
    else begin
        case (current_state2)
            SendPOSTstate: begin
                if(tx_busy) begin
                    current_state2 <= SendPOSTstate;
                end else begin
                    current_state2 <= send;
                end
            end
            
            loadmem: begin
                if(data_end) begin
                    current_state2 <= footer;
                end else begin
                    if(data_in_valid && stringindex < 209) begin   //209
                        mem[stringindex] <= data_in;   //data from fifo (must be ascii hex encoding)
                        stringindex <= stringindex + 1;
                        current_state2 <= loadmem;
                    end
                    else if(!data_in_valid && stringindex < 209) begin
                        current_state2 <= loadmem;
                    end
                    else begin
                        current_state2 <= footer;
                    end
                end
            end
            footer: begin
                if(tx_busy) begin
                    current_state2 <= footer;
                end else begin
                    current_state2 <= send;
                end
                
                mem[stringindex] <= 8'h22;  //ascii for "
                mem[stringindex + 1] <= 8'h0d; //ascii for carriage return
                mem[stringindex + 2] <= 8'h0a; //ascii for newline
            end
            send: begin
                if(i == stringindex + 2) begin
                    current_state2 <= Finished;
                end else begin
                    i <= i + 1;
                    current_state2 <= Waitsend;
                end
            end
            Waitsend: begin
                if (tx_done) begin
                    current_state2 <= send;
                end else begin
                    current_state2 <= Waitsend;
                end
            end
            Finished: begin

                current_state2 <= Waitnewline;
            end
            Waitnewline: begin
                if (j < 1600) begin   //1800 tcp //3000 http
                    current_state2 <= Waitnewline;
                    j <= j + 1;
                end else begin
                    current_state2 <= Rst1;
                end
            end
            default: begin
                current_state2 <= Rst1;
            end
        endcase
    end
end

always_comb begin
    case (current_state2)
        Rst1: begin
            tx_start = 1'b0;
            tx_data = 8'h00;
            if(start && data_in_valid && sendPOST) begin
                data_accepted = 1'b1;
                increment_table_number = 1'b0;
            end else begin
                data_accepted = 1'b0;
                increment_table_number = 1'b0;
            end
            
            //LEDR[9:0] = 10'b0000000001;
        end
        SendPOSTstate: begin
            tx_start = 1'b0;
            tx_data = 8'h00;
            data_accepted = 1'b0;
            increment_table_number = 1'b0;
        end
        loadmem: begin
            tx_start = 1'b0;
            tx_data = 8'h00;
            increment_table_number = 1'b0;
            if(data_end) begin
                data_accepted = 1'b0;
            end else begin
                if(data_in_valid && stringindex < 209) begin
                    data_accepted = 1'b1;
                end
                else if(!data_in_valid && stringindex < 209) begin
                    data_accepted = 1'b0;
                end
                else begin
                    data_accepted = 1'b0;
                end
            end
        end
        footer: begin
            tx_start = 1'b0;
            tx_data = 8'h00;
            data_accepted = 1'b0;
            increment_table_number = 1'b0;
        end
        send: begin
            tx_start = 1'b1;
            tx_data = mem[i];
            data_accepted = 1'b0;
            increment_table_number = 1'b0;
            //LEDR[9:0] = 10'b0000000010;
        end
        Waitsend: begin
            tx_start = 1'b0;
            tx_data = 8'h00;
            data_accepted = 1'b0;
            increment_table_number = 1'b0;
            //LEDR[9:0] = 10'b0000000100;
        end
        Finished: begin
            tx_start = 1'b0;
            tx_data = 8'h00;
            data_accepted = 1'b0;
            increment_table_number = 1'b1;
            //LEDR[9:0] = 10'b0000001000;
        end
        Waitnewline: begin
            tx_start = 1'b0;
            tx_data = 8'h00;
            data_accepted = 1'b0;
            increment_table_number = 1'b0;
            //LEDR[9:0] = 10'b0000010000;
        end
        default: begin
            tx_start = 1'b0;
            tx_data = 8'h00;
            data_accepted = 1'b0;
        end
    endcase

end


endmodule