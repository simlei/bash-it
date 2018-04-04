#!/usr/bin/env bats

load ../test_helper
load ../../lib/composure

@test "lib composure: stdlib_composure_keywords()" {
  run stdlib_composure_keywords
  assert_output "about author example group param version"
}
