#!/bin/bash
#
# bin/cargo-tarpaulin and bin/cargo-llvm-cov: shims that shadow the real
# coverage tools (ops bl-1f80). They refuse, say where the work goes instead,
# and deploy.sh links them into ~/.local/bin ahead of ~/.cargo/bin.
#

test_shims_refuse_and_point_at_the_builder() {
    echo "=== Testing the coverage shims: exit 1, message names the remedy ==="
    for tool in cargo-tarpaulin cargo-llvm-cov; do
        RC=0; out=$("$REPO_ROOT/bin/$tool" --version 2>&1) || RC=$?
        assert_equals 1 "$RC" "$tool exits 1"
        assert_contains "$out" "does not compile coverage" "$tool: says why"
        assert_contains "$out" "bl-remote-run" "$tool: says where instead"
        assert_contains "$out" "$tool" "$tool: names itself"
    done
    assert_equals cargo-tarpaulin "$(readlink "$REPO_ROOT/bin/cargo-llvm-cov")" "one script, two names"
}

test_shims_are_what_cargo_finds_after_deploy() {
    echo "=== Testing deploy.sh: ~/.local/bin/cargo-tarpaulin resolves to the shim ==="
    setup
    source_deploy_functions
    HOME="$TEST_DIR/home"; mkdir -p "$HOME/.cargo/bin"
    printf '#!/bin/sh\necho REAL\n' > "$HOME/.cargo/bin/cargo-tarpaulin"; chmod +x "$HOME/.cargo/bin/cargo-tarpaulin"
    (cd "$REPO_ROOT" && make_local_bin_dir > /dev/null && install_local_bins > /dev/null)
    found=$(PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/bin:/bin" command -v cargo-tarpaulin)
    assert_equals "$HOME/.local/bin/cargo-tarpaulin" "$found" "PATH order puts the shim first"
    assert_equals "$REPO_ROOT/bin/cargo-tarpaulin" "$(readlink "$found")" "and it is this repo's shim"
    assert_equals "$REPO_ROOT/bin/cargo-llvm-cov" "$(readlink "$HOME/.local/bin/cargo-llvm-cov")" "so is cargo-llvm-cov"
    teardown
}
