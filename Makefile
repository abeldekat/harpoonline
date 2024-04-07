clean:
	@rm -rf .tests/*

.tests/data/nvim:
	@mkdir -p $@

# Download 'mini.nvim' to use its 'mini.test' testing module
.tests/mini.nvim:
	@mkdir -p .tests
	git clone --filter=blob:none https://github.com/echasnovski/mini.nvim $@

# Download plenary for harpoon
.tests/plenary.nvim:
	@mkdir -p .tests
	git clone --filter=blob:none https://github.com/nvim-lua/plenary.nvim $@

# Download harpoon2
.tests/harpoon:
	@mkdir -p .tests
	git clone --filter=blob:none https://github.com/ThePrimeagen/harpoon.git $@
	cd .tests/harpoon; git checkout harpoon2

# Run all test files
test: .tests/mini.nvim .tests/harpoon .tests/plenary.nvim .tests/data/nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

# Run test from file at `$FILE` environment variable
test_file: .tests/mini.nvim .tests/harpoon .tests/plenary.nvim .tests/data/nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"
