// https://terratest.gruntwork.io/docs/#getting-started
package tests

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformMain(t *testing.T) {
	t.Parallel()

	terraformBinary := os.Getenv("TERRAFORM_BINARY")
	if len(terraformBinary) <= 0 {
		terraformBinary = "terraform"
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{

		// Point this at the specific module or example to test.
		TerraformDir: "../",

		// Switch between Terraform binaries.
		TerraformBinary: terraformBinary,

		Vars: map[string]interface{}{},
	})

	// Run terraform destroy after all other test code has run, even with errors.
	defer terraform.Destroy(t, terraformOptions)

	// Run terraform apply immediately.
	terraform.InitAndApply(t, terraformOptions)

	// Get any outputs from Terraform.
	testOutput := terraform.Output(t, terraformOptions, "submodule")

	// Run assertions to conform that outputs are what you expect.
	assert.Equal(t, "Echo: Hello, submodule", testOutput)
}