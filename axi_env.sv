class axi_env;
	axi_gen gen;
	axi_bfm bfm;
	axi_slave_bfm sbfm;
	task run();
		fork
			gen = new();
			bfm = new();
			sbfm = new();
			gen.run();
			bfm.run();
			sbfm.run();
		join
	endtask
endclass

