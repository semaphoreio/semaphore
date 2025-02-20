package aws

import (
	"regexp"
	"testing"

	"github.com/stretchr/testify/assert"
)

func Test__HandleWildcards(t *testing.T) {
	wildcardAssert(t, "myrole", "myrole", true)
	wildcardAssert(t, "myrole", "notmyrole", false)
	wildcardAssert(t, "myrole*", "myrole", true)
	wildcardAssert(t, "myrole*", "myrole1", true)
	wildcardAssert(t, "myrole*", "myrolefirst", true)
	wildcardAssert(t, "myrole*", "notmyrole", false)
	wildcardAssert(t, "*myrole", "myrole", true)
	wildcardAssert(t, "*myrole", "1myrole", true)
	wildcardAssert(t, "*myrole", "firstmyrole", true)
	wildcardAssert(t, "*myrole", "myrolenot", false)
}

func Test__MatchesAnyRole(t *testing.T) {
	assert.False(t, MatchesAnyRole([]string{}, "role1"))
	assert.False(t, MatchesAnyRole([]string{"role1", "role2*"}, "role"))
	assert.True(t, MatchesAnyRole([]string{"role1", "role2"}, "role1"))
	assert.True(t, MatchesAnyRole([]string{"role1", "role2"}, "role2"))
	assert.False(t, MatchesAnyRole([]string{"role1", "role2"}, "role3"))
	assert.True(t, MatchesAnyRole([]string{"role1", "role2*"}, "role1"))
	assert.True(t, MatchesAnyRole([]string{"role1", "role2*"}, "role2_1234"))
}

func Test__Validate(t *testing.T) {
	t.Run("untrusted account", func(t *testing.T) {
		_, err := Validate(
			"5678", []string{"role1"},
			&GetCallerIdentityResult{Account: "1234", Arn: "arn:aws:iam::1234:assumed-role/role1/i-1234"},
		)

		assert.ErrorContains(t, err, "AWS account '1234' is not allowed")
	})

	t.Run("only assumed-role ARNs are allowed", func(t *testing.T) {
		_, err := Validate(
			"1234", []string{"role1"},
			&GetCallerIdentityResult{Account: "1234", Arn: "arn:aws:iam::1234:user/user1"},
		)

		assert.ErrorContains(t, err, "ARN 'arn:aws:iam::1234:user/user1' is not allowed")
	})

	t.Run("untrusted role", func(t *testing.T) {
		_, err := Validate(
			"1234", []string{"role1", "role2"},
			&GetCallerIdentityResult{Account: "1234", Arn: "arn:aws:iam::1234:assumed-role/role3/i-1234"},
		)

		assert.ErrorContains(t, err, "ARN 'arn:aws:iam::1234:assumed-role/role3/i-1234' is not allowed")
	})

	t.Run("validation passes and session id is returned", func(t *testing.T) {
		name, err := Validate(
			"1234", []string{"role1", "role2"},
			&GetCallerIdentityResult{Account: "1234", Arn: "arn:aws:sts::1234:assumed-role/role1/i-1234"},
		)

		assert.NoError(t, err)
		assert.Equal(t, "i-1234", name)
	})
}

func wildcardAssert(t *testing.T, pattern, value string, expected bool) {
	match, _ := regexp.MatchString(HandleWildcards(pattern), value)
	assert.Equal(t, expected, match)
}
