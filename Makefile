# Download 'mini.nvim' to use its 'mini.test' testing module
deps/mini.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/echasnovski/mini.nvim $@

# Download harpoon2
deps/harpoon:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/ThePrimeagen/harpoon.git $@
	cd deps/harpoon; git checkout harpoon2

# Run all test files
test: deps/mini.nvim deps/harpoon
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

# Run test from file at `$FILE` environment variable
test_file: deps/mini.nvim deps/harpoon
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"
