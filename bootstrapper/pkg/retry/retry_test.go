package retry

import (
	"fmt"
	"testing"
	"time"
)

func TestWithConstantWait(t *testing.T) {
	type args struct {
		task        string
		maxAttempts int
		wait        time.Duration
		f           func() error
	}

	tmpCounter := 0
	tests := []struct {
		name    string
		args    args
		wantErr bool
	}{
		{
			name: "Two attempts should work",
			args: args{
				maxAttempts: 2,
				wait:        1 * time.Second,
				f: func() error {
					return nil
				},
			},
			wantErr: false,
		},
		{
			name: "Negative attempts should run at least once",
			args: args{
				maxAttempts: -1,
				wait:        2 * time.Second,
				f: func() error {
					return nil
				},
			},
			wantErr: false,
		},
		{
			name: "Should retry once",
			args: args{
				maxAttempts: 1,
				wait:        1 * time.Second,
				f: func() error {
					if tmpCounter == 0 {
						tmpCounter++
						return fmt.Errorf("first time error")
					}
					return nil
				},
			},
		},
		{
			name: "Should error",
			args: args{
				maxAttempts: 2,
				wait:        1 * time.Second,
				f: func() error {
					return fmt.Errorf("first time error")
				},
			},
			wantErr: true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if err := WithConstantWait(tt.args.task, tt.args.maxAttempts, tt.args.wait, tt.args.f); (err != nil) != tt.wantErr {
				t.Errorf("WithConstantWait() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}
