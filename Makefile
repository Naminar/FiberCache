
gen: init_submodule
	python3 FakeRAM2.0/run.py example_input_file.cfg

init_submodule: 
	chmod +x apply_patch.sh
	./apply_patch.sh