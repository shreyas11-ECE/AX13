class axi_slave_bfm;
	virtual axi_interface svif;///virtual interface
	axi_tx tx;	
	axi_tx wr_tx[int];//associative array
	axi_tx rd_tx[int]; //read data and read address channel
	int data_size;
	int data_in_bytes;
	int temp_id;
	int prev_wdata;
	bit[3:0] prev_wstrb;
	reg[7:0]  mem [10000:0];
	int count;
	
	task run();
		svif = common::vif;
		forever begin//Every clock cycle check all request ROM master
			@(posedge svif.aclk);
			//If in posedge of aclk aresetn is 0 then all the signals move to default values
			if(svif.aresetn==1'b0)begin
				svif.awready = 1'bx;
				svif.wready = 1'bx;
				svif.bid = 4'bxxxx;
				svif.bvalid = 1'bx;
				svif.bresp = 2'bxx;
				svif.arready = 1'bx;
				svif.arid = 4'bxxxx;
				svif.rresp = 2'bxx;
				svif.rvalid = 1'bx;
				svif.rdata = 32'hxxxxxxxx;
				svif.rlast = 1'bx;
				for(int i =0;i<10000;i++)begin
					mem[i]=0;
				end
			end
			else begin
			       //	for(int i =0;i<10000;i++)begin
				//	mem[i]=0;
				//end
	//aresetn = 1
				//If master is not sending valid address and control data Write address channel
				if(svif.awvalid==1'b0)
					svif.awready = 1'b0;
				//If master is not sending valid write data and strb value Write data channel
				if(svif.wvalid==1'b0)
					svif.wready = 1'b0;
				//If master is not ready to recive response Write response channel
				if(svif.bready==1'b0)
					svif.bvalid = 1'b0;
				//If master is not sending valid read address Read address channel
				if(svif.arvalid==1'b0)
					svif.arready = 1'b0;
				//Master is not ready recieve read data Read data/response channel
				if(svif.rready==1'b0)
					svif.rvalid = 1'b0;
				//Master sending valid address and controlsignal data Write address channel
				if(svif.awvalid==1)begin
					@(posedge svif.aclk);
					svif.awready = 1'b1;//Slave is ready to recive address and control signal
					wr_tx[svif.awid] = new();
					wr_tx[svif.awid].awaddr = svif.awaddr;
					wr_tx[svif.awid].awlen = svif.awlen;
					wr_tx[svif.awid].awsize = svif.awsize;
					wr_tx[svif.awid].awburst = svif.awburst;
					wr_tx[svif.awid].awprot = svif.awprot;
					wr_tx[svif.awid].awcache = svif.awcache;
					wr_tx[svif.awid].awlock = svif.awlock;
					wr_tx[svif.awid].awid = svif.awid; 
					//@(posedge svif.aclk);
				end//End of write address channel

					//Write data channel
				if(svif.wvalid==1)begin//Master sending valid wdata
					@(posedge svif.aclk);
				
				       svif.wready <= 1;//Slave sending bit 1 indicating it is ready to recieve data
				       //--------------------------------------------------
				       wr_tx[svif.wid].wid = svif.wid;
				       $display("wid:%0h, awid:%0h, awlen:%0h, awaddr:%0h, awsize:%0h, awburst:%0h  in %0t (Slave BFM)", wr_tx[svif.wid].wid, wr_tx[svif.wid].awlen, wr_tx[svif.wid].awlen, wr_tx[svif.wid].awaddr, wr_tx[svif.wid].awsize, wr_tx[svif.wid].awburst , $time);
				
				       
				       data_size = $size(svif.wdata);//TO check wdata size in bits
				       data_in_bytes = data_size/8;//wdata size in bytes
				       //-------------------------------------------------

				       if(svif.awburst==1)begin//Increment transcation
				       //Master sending howmany transfer
		  			       for(int i = 0; i<=svif.awlen; i++)begin
						       wait(prev_wdata!=svif.wdata|| prev_wstrb!=svif.wstrb);
						       //#0;
						       	$display("Inside slave BFM awaddr is %0h wdata is %0h for wid %0h of %0h transfer with wstrb is %0h at time:%0t", wr_tx[svif.wid].awaddr,svif.wdata, wr_tx[svif.wid].wid, i, svif.wstrb, $time);
						       count = 0;
						       	wr_tx[svif.wid].awaddr = wr_tx[svif.wid].awaddr - (wr_tx[svif.wid].awaddr)%2**wr_tx[svif.wid].awsize; //aligned address conversion
						       for(int j = 0; j<data_in_bytes; j++) begin //if wdata size is 32 bits then for loop will work 4 times and if wdata size is 128 bits the loop will work 16 times and so 
								if(svif.wstrb[j]==1)begin//Checks every bit  of wstrb 
								      	//$dsiplay("wstrb[%0h] is %0h",j,svif.wstrb[j]);
									mem[wr_tx[svif.wid].awaddr+count] = svif.wdata[j*8 +:  8];
									$display("%0h transfer %0h byte data stored in %0h address is %0h at %0t and count = %0h ", i, j, wr_tx[svif.wid].awaddr+count, mem[wr_tx[svif.wid].awaddr+count], $time, count ); 
								end//wstrb condition
							//	if(svif.wstrb[j]==0)
							//		mem[wr_tx[svif.wid].awaddr+count] = 0;
								count = count+1;
							end
								prev_wdata = svif.wdata;
								prev_wstrb = svif.wstrb;
								wr_tx[svif.wid].awaddr = wr_tx[svif.wid].awaddr + 4;
								$display("prev_wstrb is %0h and prev_wdata is %0h",prev_wstrb, prev_wdata);
								//next transfer address calculation	
								@(posedge svif.aclk);
							//	@(posedge svif.aclk);
				
						end //awlen for loop
				       end//awbusrt condtion
				  end//wvalid condtional statement

				  
				  //Write response channel 
				  if(svif.bready==1)begin
					if(svif.wlast==1)begin
						svif.bvalid = 1;
						svif.bid = svif.wid;
						svif.bresp = 2'b00;
					end//end of wlast condtion
				  end//end of write response channel
				  //Read address channel
				  if(svif.arvalid==1)begin
					 // wait(svif.awvalid!=0);
					  svif.arready = 1'b1;//slave is ready to recive address and control signal
					  //read address channel
					  rd_tx[svif.arid] = new();
					 rd_tx[svif.arid].araddr = svif.araddr;
						rd_tx[svif.arid].arlen = svif.arlen;
						rd_tx[svif.arid].arsize = svif.arsize;
						rd_tx[svif.arid].arburst = svif.arburst;
						rd_tx[svif.arid].arprot = svif.arprot;
						rd_tx[svif.arid].arcache = svif.arcache;
						rd_tx[svif.arid].arlock = svif.arlock;
						rd_tx[svif.arid].arid = svif.arid;
					end//End of read address channel

					//Read data channel
					if(svif.rready==1'b1)begin
					//	wait(svif.wlast!=0);
						svif.rvalid = 1;
						temp_id = svif.arid;
						rd_tx.first(temp_id);
						rd_tx[temp_id].araddr = svif.araddr;
					

						//Check for type of transaction
						if(svif.arburst==1)begin

							//Number of transfer slave has to send to master is decided by arlen
							for(int i =0;i<=svif.arlen;i++)begin

								rd_tx[temp_id].araddr = rd_tx[temp_id].araddr - (rd_tx[temp_id].araddr%2**rd_tx[temp_id].arsize);
								//How many bytes of data has to be send
								count = 0;
								$display("Araddr insise read data channel in slave BFM %0h",rd_tx[temp_id].araddr);
								//Slave needs to send data from memory
								for(int j = 0;j<($size(svif.wdata)/8);j++)begin
									svif.rdata[j*8 +: 8] = mem[rd_tx[temp_id].araddr+count];
									$display("Mem[%0h] is %0h", rd_tx[temp_id].araddr+count,mem[rd_tx[temp_id].araddr+count]); 
									count = count+1;
								end
								rd_tx[temp_id].araddr = rd_tx[temp_id].araddr + 4;
								svif.rid = temp_id;
								svif.rresp = 2'b00;
								if(i==svif.arlen)//Checking for last transfer 
								svif.rlast = 1;
								@(posedge svif.aclk);
							end//End of transfer
					end
					rd_tx.delete(temp_id);
					svif.rvalid = 1'b0;
				end//End of read data channel
			end//else condition of areser=tn
		end //forever looop
		common::vif = svif;			
	endtask
endclass

