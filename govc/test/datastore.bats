#!/usr/bin/env bats

load test_helper

upload_file() {
  file=$($mktemp --tmpdir govc-test-XXXXX)
  name=$(basename ${file})
  echo "Hello world" > ${file}

  run govc datastore.upload "${file}" "${name}"
  assert_success

  rm -f "${file}"
  echo "${name}"
}

@test "datastore.ls" {
  name=$(upload_file)

  # Single argument
  run govc datastore.ls "${name}"
  assert_success
  [ ${#lines[@]} -eq 1 ]

  # Multiple arguments
  run govc datastore.ls "${name}" "${name}"
  assert_success
  [ ${#lines[@]} -eq 2 ]

  # Pattern argument
  run govc datastore.ls "./govc-test-*"
  assert_success
  [ ${#lines[@]} -ge 1 ]

  # Long listing
  run govc datastore.ls -l "./govc-test-*"
  assert_success
  assert_equal "12B" $(awk '{ print $1 }' <<<${output})
}

@test "datastore.rm" {
  name=$(upload_file)

  # Not found is a failure
  run govc datastore.rm "${name}.notfound"
  assert_failure
  assert_matches "govc: File .* was not found" "${output}"

  # Not found is NOT a failure with the force flag
  run govc datastore.rm -f "${name}.notfound"
  assert_success
  assert_empty "${output}"

  # Verify the file is present
  run govc datastore.ls "${name}"
  assert_success

  # Delete the file
  run govc datastore.rm "${name}"
  assert_success
  assert_empty "${output}"

  # Verify the file is gone
  run govc datastore.ls "${name}"
  assert_failure
}

@test "datastore.info" {
  run govc datastore.info enoent
  assert_failure

  run govc datastore.info
  assert_success
  [ ${#lines[@]} -gt 1 ]
}


@test "datastore.mkdir" {
  name=$(new_id)

  # Not supported datastore type is a failure
  run govc datastore.mkdir -namespace "notfound"
  assert_failure
  assert_matches "govc: ServerFaultCode: .*" "${output}"

  run govc datastore.mkdir "${name}"
  assert_success
  assert_empty "${output}"

  # Verify the dir is present
  run govc datastore.ls "${name}"
  assert_success

  # Delete the dir on an unsupported datastore type is a failure
  run govc datastore.rm -namespace "${name}"
  assert_failure
  assert_matches "govc: ServerFaultCode: .*" "${output}"

  # Delete the dir
  run govc datastore.rm "${name}"
  assert_success
  assert_empty "${output}"

  # Verify the dir is gone
  run govc datastore.ls "${name}"
  assert_failure
}

@test "datastore.download" {
  name=$(upload_file)
  run govc datastore.download "$name" -
  assert_success
  assert_output "Hello world"

  run govc datastore.download "$name" "$TMPDIR/$name"
  assert_success
  run cat "$TMPDIR/$name"
  assert_output "Hello world"
  rm "$TMPDIR/$name"
}

@test "datastore.upload" {
  name=$(new_id)
  echo -n "Hello world" | govc datastore.upload - "$name"

  run govc datastore.download "$name" -
  assert_success
  assert_output "Hello world"
}
