/*class axi_bfm;
    axi_tx tx;
    virtual axi_interface mvif;

    //getting pointed vitual interface from top module
    axi_tx wr_tx[int];
    int data_size_in_bytes;
    int each_beat_active_bytes;
    int offset_addr;
    int aligned_addr;
    int wstrb_bit;

    task run();
        mvif = common::vif;
        forever begin  //every posedge of clock it get the data 
            @(posedge mvif.aclk);
            common::gen2bfm.get(tx); //get the randomized data from generator 
    

            //put all randomized data into interface    
            //1.write address channel 
            //2.write data channel 
            //3.write response channel 
            //1.read address channel 
            //2.read response channel 
            //write then read 
            if (tx.wr_rd == write_then_read) begin
                //1.write address channel
                write_address_channel();
                //2.write data channel
                write_data_channel();
                //3.write response channel
                write_response_channel();
                //4.read address channel 
                read_address_channel();
                //5.read data channel  
                read_data_channel();    
            end

            //write  parallel read 
            if (tx.wr_rd == write_parallel_read)
                fork 
                    begin
                        //1.write address channel
                        write_address_channel();
                        //2.write data  channel 
                        write_data_channel();
                        //3.write response channel
                        write_response_channel();
                    end
                    begin
                        //4.read address channel 
                        read_address_channel();
                        //5.read data cahnnel 
                        read_data_channel();
                    end
                join

            //write only 
            if (tx.wr_rd == write_only) begin
                //1.write address channel 
                write_address_channel();
                //2.write data channel 
                write_data_channel();
                //3.write response channel 
                write_response_channel();
            end 

            //read only
            if (tx.wr_rd == read_only) begin
                //1.read address channel 
                read_address_channel();
                //2.read response channel 
                read_data_channel();
            end
        end // forever
    endtask


    //1.write address channel task put all randomized data to the 
    task write_address_channel(); //first clock cycle 
        mvif.awaddr  <= tx.awaddr;
        mvif.awid    <= tx.awid;
        mvif.awvalid <= 1;
        mvif.awlen   <= tx.awlen;
        mvif.awsize  <= tx.awsize;
        mvif.awburst <= tx.awburst;
        mvif.awlock  <= tx.awlock;
        mvif.awprot  <= tx.awprot;
        //master need to wait until ready come from slave 
        wait (mvif.awready == 1); //secondclock cycle
        //store all write address signals to one associative array 
        wr_tx[tx.awid] = new();
        wr_tx[tx.awid].awaddr = tx.awaddr;
        wr_tx[tx.awid].awid   = tx.awid;
        wr_tx[tx.awid].awlen  = tx.awlen;
        wr_tx[tx.awid].awsize = tx.awsize;
        wr_tx[tx.awid].awprot = tx.awprot;
        wr_tx[tx.awid].awcache= tx.awcache;
        wr_tx[tx.awid].awburst= tx.awburst;

        //let us assume  awaddr=0 awlen=3 awsize=2 wdata size 32bit awbrst=1 awid=5
        //wdata[0]=32'h11223344 [1]=32'baabbccdd [2]=32'ha1b1c1d1 
        //hence it stores   wr_tx[5].awaddr=0   wr_tx[5].awlen=3    wr-tx[5].awsize=2
        @(posedge mvif.aclk);
        mvif.awvalid = 0; //inside slave awready=0;
    endtask



    //2.write data channel task
    task write_data_channel();
        //master can able to send overlaping transaction out of order 
        //transaction wstrb logic //master need to generate multiple transfers and   proper wstrob 
	
// --- Safety checks before accessing ---
if (!wr_tx.exists(mvif.wid)) begin
    $fatal("BFM ERROR: wr_tx entry for wid=%0d not found!", mvif.wid);
end
if (tx.wdata.size() == 0) begin
    $fatal("BFM ERROR: tx.wdata array is empty before pop_back()");
end

for (int i = 0; i <= wr_tx[mvif.wid].awlen; i++) begin
    mvif.wdata = tx.wdata.pop_back(); //get the data also delet the data from array 
            mvif.wid   = tx.wid;
            mvif.wvalid = 1;
            if (i == wr_tx[mvif.wid].awlen) mvif.wlast = 1; //last transfer 
            //each transfer should generate the wstrob(aligned ,unaligned,narrow transfer)
            data_size_in_bytes = ($bits(mvif.wdata) / 8); //wdata size 32 data_size_in_bytes =4,
            //how many bytes are active in each bit = by using awsize =2**awsize
            each_beat_active_bytes = (2 ** wr_tx[mvif.wid].awsize);
            //aligned or unaligned address(stat address)
            offset_addr = wr_tx[mvif.wid].awaddr % data_size_in_bytes;
            //convert unaligned address to aligned address
            aligned_addr = wr_tx[mvif.wid].awaddr - (wr_tx[mvif.wid].awaddr % (2 ** wr_tx[mvif.wid].awsize));
            tx.wstrb = 0;
            //wdata size 64 bit 8bytes awsize 2 awaddr=7
            //7%8=7(this is present in 7th position )
            //1.if address is aligned 
            if ((wr_tx[mvif.wid].awaddr % each_beat_active_bytes) == 0) begin
                for (int j = 0; j < each_beat_active_bytes; j++) begin
                    wstrb_bit = (offset_addr + j) % data_size_in_bytes;
                    tx.wstrb[wstrb_bit] = 1'b1;
                end
            end
            //2.address is unaligne
            if ((wr_tx[mvif.wid].awaddr % each_beat_active_bytes) != 0) begin
                for (int j = offset_addr; j < (aligned_addr + each_beat_active_bytes); j++) begin
                    tx.wstrb[j] = 1'b1;
                end
            end 
            mvif.wstrb = tx.wstrb;
            //convert unaligned address to aligned address
            wr_tx[mvif.wid].awaddr = wr_tx[mvif.wid].awaddr - (wr_tx[mvif.wid].awaddr % (2 ** wr_tx[mvif.wid].awsize));
            //next transfer start address
            wr_tx[mvif.wid].awaddr = wr_tx[mvif.wid].awaddr + 2 ** wr_tx[mvif.wid].awsize; //4+4=8
            wait (mvif.wready == 1); //waiting each transfer untill wready comes from slave 

            @(posedge mvif.aclk); //3rd clock cycle 
            mvif.wlast = 0;
            mvif.wvalid = 0;
        end // for
    endtask




    //3.write response channel task
    task write_response_channel(); //we need to send only bready slave 
        mvif.bready = 1; //master is ready to recive 
        wait (mvif.bvalid == 1); //slave sends response to master     
    endtask



    //4.read address channel task
    task read_address_channel();
        mvif.araddr  = tx.awaddr;
        mvif.arid    = tx.awid;
        mvif.arvalid = 1;
        mvif.arlen   = tx.awlen;
        mvif.arsize  = tx.awsize;
        mvif.arburst = tx.awburst;
        mvif.arlock  = tx.awlock;
        mvif.arprot  = tx.arprot;
        //master need to wait until ready come from slave 
        wait (mvif.awready == 1);
        @(posedge mvif.aclk);
        mvif.awvalid = 0; //inside slave awready=0;
    endtask
    //5.read data channel task
    task read_data_channel();
        mvif.rready = 1;
        wait (mvif.rvalid == 0);
    endtask



      /*  //we need to put all the radbomized informtion to interface
        //write address
        common::vif.awaddr = tx.awaddr;
        common::vif.awlen  = tx.awlen;
        common::vif.awsize = tx.awsize;
        common::vif.awburst= tx.awburst;
        common::vif.awvalid= tx.awvalid;

        //write data channel
        for (int i=0; i<=common::vif.awlen; i++) begin
            @(posedge common::vif.aclk);
            common::vif.wdata = tx.wdata.pop_back(); //get the data after delete the from array
            common::vif.wvalid= 1;
            common::vif.wstrb = 4'b1111; 
    //end //forever 
//endtask
endclass
*/


class axi_bfm;
	axi_tx tx;
	virtual axi_interface mvif;
	write_read wr_rd;
	axi_tx wr_tx[int];
	int wdata_size_bytes;
	int active_bytes;
	int offset_address;
	int aligned_address;
	int wstrb_bit;
	int c;


	task run();
		mvif = common::vif;
		forever begin
			tx = new();
			common::gen2bfm.get(tx);
			$display("Operation = %0s",tx.wr_rd);
			if(tx.wr_rd==write_then_read)begin
				//1. Write address channel
				write_address_channel();
				//2. Write data channel
				write_data_channel();	
				//3. Write response channel
				write_response_channel();
				//4. Read address channel
			//	wait(mvif.wlast = 1'b1);
				read_address_channel();	
				//5. Read data channel
				read_data_channel();
			end//Write then read

			//Write and read parallel
			if(tx.wr_rd==write_parallel_read)fork
				begin
					//1. Write address channel
					write_address_channel();
					//2. Write data channel
					write_data_channel();
					//3. Write response channel
					write_response_channel();
       				end
				begin
					//1.Read address channel
					read_address_channel();
					//2.Read data channel
					read_data_channel();
		       		end
			join//Write parallel 

			//Write onnly
			if(tx.wr_rd==write_only)begin
				if(common::overlapping==1 || common::out_of_order==1)begin
					if(tx.awvalid==1 && tx.wvalid==1'b0)
						write_address_channel();
					if(tx.wvalid==1'b1)begin
						write_data_channel();
						write_response_channel();
					end
				end
				else begin//There is out of order or overlapping then normal write transaction happens
					//1. Write address channel
					write_address_channel();
					//2. Write data channel
					write_data_channel();
					//3. Write response channel
					write_response_channel();
				end 
			end//write only

			//Read only 
			if(tx.wr_rd==read_only)begin
				//1.Read address channel
				read_address_channel();
				//2.Read data channel
				read_data_channel();
			end//Read only
			common::vif = mvif;
			@(posedge mvif.aclk);
		end
	endtask

	//Create five separate task each for different channel
	
	//1. Write address channel task
	task write_address_channel();
		//Put all address and control signals to interface
		mvif.awaddr <= tx.awaddr;
		mvif.awlen <= tx.awlen;
		mvif.awsize <= tx.awsize;
		mvif.awburst <= tx.awburst;
		mvif.awid <= tx.awid;
		mvif.awlock <= tx.awlock;
		mvif.awcache <= tx.awcache;
		mvif.awprot <= tx.awprot;
		mvif.awvalid <= 1'b1;
		//master need to wait until ready come from slave 
		wait(mvif.awready==1'b1);
		//Store all the address and control signal into one associative array
		wr_tx[tx.awid] = new();
		wr_tx[tx.awid].awaddr = tx.awaddr;
		wr_tx[tx.awid].awid = tx.awid;
		$display("awid inn write address channel is %0h",tx.awid);
		wr_tx[tx.awid].awsize = tx.awsize;
		wr_tx[tx.awid].awburst = tx.awburst;
		wr_tx[tx.awid].awlock = tx.awlock;
		wr_tx[tx.awid].awlen = tx.awlen;
		wr_tx[tx.awid].awprot = tx.awprot;
		wr_tx[tx.awid].awcache = tx.awcache;
		wr_tx[tx.awid].awvalid = 1'b1;
		@(posedge mvif.aclk);
		mvif.awvalid <= 1'b0;
	endtask//Task of Write_address

	//2. Write data channel
	task write_data_channel();
		@(posedge mvif.aclk);
	//	write_address_channel();
		mvif.bready <= 1'b1;
		//@(posedge mvif.aclk);
	//	wr_tx[tx.wid] = new();
		wr_tx[tx.wid].wid = tx.wid;
		mvif.wid <= tx.wid;		
		$display("wid:%0h, awid:%0h, awlen:%0h, awaddr:%0h, awsize:%0h, awburst:%0h  in %0t (Master BFM)", wr_tx[tx.wid].wid, wr_tx[tx.wid].awlen, wr_tx[tx.wid].awlen, wr_tx[tx.wid].awaddr, wr_tx[tx.wid].awsize, wr_tx[tx.wid].awburst , $time);
		for(int i = 0; i<=wr_tx[tx.wid].awlen; i++)begin
			$display(" %0h transfer inside master BFM with wid %0h",i, wr_tx[tx.wid].wid);
			fork
				//Statement 01
				if(common::overlapping==1'b1)begin
					if(tx.awvalid==1'b1)
						write_address_channel();
				end
				//Statement 02
				begin
				mvif.wdata <= tx.wdata.pop_back();//Get the data also deletes the data from the array
				mvif.wvalid <= 1;
				wdata_size_bytes = ($size(mvif.wdata)/8);
				//2.Number of active address in each transfer
				active_bytes = 2**wr_tx[tx.wid].awsize;
				//3.Start address is aligned or unaligend and if unaligned what is remainder(offset address)
				offset_address = wr_tx[tx.wid].awaddr%wdata_size_bytes;//This mainly related to narrow transfer
				//4.Convert aligned address to unaligned address
				aligned_address = wr_tx[tx.wid].awaddr - (wr_tx[tx.wid].awaddr%active_bytes);
				c = wr_tx[tx.wid].awaddr - aligned_address;
				$display(" %0h transfer awaddr: %0h wdata is %0h with size in bytes is %0h and Number of active bytes is %0h with offset address is %0h  at %0t", i,wr_tx[tx.wid].awaddr, mvif.wdata,wdata_size_bytes, active_bytes, offset_address, $time);
				//wstrb logic
				tx.wstrb = 0;
				//1. Aligned address
				if((wr_tx[tx.wid].awaddr%2**wr_tx[tx.wid].awsize)==0)begin 
					for(int j = 0; j<active_bytes; j = j+1)begin 
						wstrb_bit = (offset_address+j)%(wdata_size_bytes);
						tx.wstrb[wstrb_bit]=1'b1;
					end
				end//address is aligned 
				//2.Unaligned address
				else begin
					for(int j=offset_address;j<(wr_tx[tx.wid].awsize+offset_address+c);j++)begin 
						tx.wstrb[j] = 1'b1;
					end
				end//Address is unaligned 
				$display("Wstrb of %0h transfer is %0h", i, tx.wstrb);
				mvif.wstrb <= tx.wstrb;
				//Convert unaligned address to aligned address
				wr_tx[tx.wid].awaddr = wr_tx[tx.wid].awaddr - (wr_tx[tx.wid].awaddr%2**wr_tx[tx.wid].awsize);
				//Next transfer address
				wr_tx[tx.wid].awaddr = wr_tx[tx.wid].awaddr+ 2**wr_tx[tx.wid].awsize;
				$display("Awaddr for %0h transfer is %0h", i+1, wr_tx[tx.wid].awsize);
				if(i==wr_tx[tx.wid].awlen)begin
					mvif.wlast <= 1'b1;
				end
				else 
					mvif.wlast <= 1'b0;

				wait(mvif.wready);
				//Master needs to wait until ready comes slave
				@(posedge mvif.aclk);//After this make wlast low
			//	@(posedge mvif.aclk);
			//	mvif.wvalid <= 1'b0;
				mvif.wlast <= 1'b0;
				end
			join
		end//No. of transfers
		mvif.wvalid = 1'b0;
		endtask//Task of write_data_channel
	

	//3. Write response channel
	task write_response_channel();
	//	mvif.bready = 1'b1;
		wait(mvif.bvalid==1'b1);
		if(common::out_of_order||common::overlapping)begin
		@(posedge mvif.aclk);
		@(posedge mvif.aclk);
		mvif.bready = 0;
	endtask//Task of write_response_channel

	//4. Read address channel
	task read_address_channel();
		//Put all address and control signals to interface
		mvif.araddr = tx.araddr;
		mvif.arlen = tx.arlen;
		mvif.arsize = tx.arsize;
		mvif.arburst = tx.arburst;
		mvif.arid = tx.arid;
		mvif.arlock = tx.arlock;
		mvif.arcache = tx.arcache;
		mvif.arprot = tx.arprot;
		mvif.arvalid = 1;
		wait(mvif.arready==1);
		@(posedge mvif.aclk);
		mvif.arvalid = 0;
	endtask//Task of read_address_channel

	//5. Read data channel
	task read_data_channel();
		mvif.rready <= 1;
		wait(mvif.rvalid==1'b1);
		@(posedge mvif.aclk);
		mvif.rready <= 1'b0;
	endtask//Task of read_data_channel
endclass

