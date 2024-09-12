variables {}

run "plan_should_work" {
  command = plan

  module {
    source = "./"
  }

  assert {
    condition     = output.submodule == "Echo: Hello, submodule"
    error_message = "The output does not match the input."
  }
}