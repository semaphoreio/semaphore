package aggregator

import (
	"reflect"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
)

func Test_calculateMetric(t *testing.T) {
	type args struct {
		runs []entity.PipelineRun
	}
	tests := []struct {
		name string
		args args
		want entity.MetricPoint
	}{
		{
			name: "no runs",
			args: args{},
			want: entity.MetricPoint{},
		},
		{
			name: "1 run",
			args: args{[]entity.PipelineRun{
				{
					PipelineId:       uuid.New(),
					ProjectId:        uuid.New(),
					BranchId:         uuid.New(),
					BranchName:       "master",
					PipelineFileName: "semaphore.yml",
					Result:           "TEST",
					Reason:           "PASSED",
					RunningAt:        time.Now(),
					DoneAt:           time.Now().Add(time.Hour),
				},
			}},
			want: entity.MetricPoint{
				Frequency: entity.Frequency{Count: 1},
				Performance: entity.Performance{
					StdDev: 0,
					Avg:    3600,
					Median: 3600,
					Max:    3600,
					Min:    3600,
					P95:    3600,
				},
				Reliability: entity.Reliability{
					Total: 1,
				},
			},
		},
		{
			name: "Multiple runs",
			args: args{
				[]entity.PipelineRun{
					{
						PipelineId:       uuid.New(),
						ProjectId:        uuid.New(),
						BranchId:         uuid.New(),
						BranchName:       "master",
						PipelineFileName: "file",
						Result:           "PASSED",
						Reason:           "TEST",
						RunningAt:        time.Now(),
						DoneAt:           time.Now().Add(time.Hour * 1),
					},
					{
						PipelineId:       uuid.New(),
						ProjectId:        uuid.New(),
						BranchId:         uuid.New(),
						BranchName:       "master",
						PipelineFileName: "file",
						Result:           "PASSED",
						Reason:           "TEST",
						RunningAt:        time.Now(),
						DoneAt:           time.Now().Add(time.Hour * 2),
					},
				},
			},
			want: entity.MetricPoint{
				Frequency: entity.Frequency{Count: 2},
				Performance: entity.Performance{
					StdDev: 1800,
					Avg:    5400,
					Median: 5400,
					Max:    7200,
					Min:    3600,
					P95:    7200,
				},
				Reliability: entity.Reliability{
					Total:  2,
					Passed: 2,
				},
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := calculateMetric(tt.args.runs); !reflect.DeepEqual(got, tt.want) {
				t.Errorf("calculateMetric() = %v, want %v", got, tt.want)
			}
		})
	}
}

func Test_calculateMetricForRuns(t *testing.T) {

	type args struct {
		runs []entity.PipelineRun
	}
	tests := []struct {
		name string
		args args
		want entity.Metrics
	}{
		{
			name: "empty runs",
			args: args{},
			want: entity.Metrics{},
		},
		{
			name: "two passed runs",
			args: args{
				[]entity.PipelineRun{
					createFakeRun(1, "PASSED"),
					createFakeRun(2, "PASSED"),
				},
			},
			want: entity.Metrics{
				All: entity.MetricPoint{
					Frequency: entity.Frequency{Count: 2},
					Performance: entity.Performance{
						StdDev: 1800,
						Avg:    5400,
						Median: 5400,
						Max:    7200,
						Min:    3600,
						P95:    7200,
					},
					Reliability: entity.Reliability{
						Total:  2,
						Passed: 2,
					},
				},
				Passed: entity.MetricPoint{
					Frequency: entity.Frequency{Count: 2},
					Performance: entity.Performance{
						StdDev: 1800,
						Avg:    5400,
						Median: 5400,
						Max:    7200,
						Min:    3600,
						P95:    7200,
					},
					Reliability: entity.Reliability{
						Total:  2,
						Passed: 2,
					},
				},
				Failed: entity.MetricPoint{},
			},
		},
		{
			name: "two failed runs",
			args: args{
				[]entity.PipelineRun{
					createFakeRun(1, "FAILED"),
					createFakeRun(2, "FAILED"),
				},
			},
			want: entity.Metrics{
				All: entity.MetricPoint{
					Frequency: entity.Frequency{Count: 2},
					Performance: entity.Performance{
						StdDev: 1800,
						Avg:    5400,
						Median: 5400,
						Max:    7200,
						Min:    3600,
						P95:    7200,
					}, Reliability: entity.Reliability{
						Total:   2,
						Stopped: 0,
						Failed:  2,
						Passed:  0,
					},
				},
				Failed: entity.MetricPoint{Frequency: entity.Frequency{Count: 2},
					Performance: entity.Performance{
						StdDev: 1800,
						Avg:    5400,
						Median: 5400,
						Max:    7200,
						Min:    3600,
						P95:    7200,
					},
					Reliability: entity.Reliability{
						Total:   2,
						Stopped: 0,
						Failed:  2,
						Passed:  0,
					},
				},
				Passed: entity.MetricPoint{},
			},
		},
		{
			name: "two passed and one failed runs",
			args: args{
				[]entity.PipelineRun{
					createFakeRun(1, "PASSED"),
					createFakeRun(1, "PASSED"),
					createFakeRun(1, "FAILED"),
				},
			},
			want: entity.Metrics{
				All: entity.MetricPoint{
					Frequency: entity.Frequency{Count: 3},
					Performance: entity.Performance{
						StdDev: 0,
						Avg:    3600,
						Median: 3600,
						Max:    3600,
						Min:    3600,
						P95:    3600,
					},
					Reliability: entity.Reliability{
						Total:   3,
						Stopped: 0,
						Failed:  1,
						Passed:  2,
					},
				},
				Passed: entity.MetricPoint{
					Frequency: entity.Frequency{Count: 2},
					Performance: entity.Performance{
						StdDev: 0,
						Avg:    3600,
						Median: 3600,
						Max:    3600,
						Min:    3600,
						P95:    3600,
					},
					Reliability: entity.Reliability{
						Total:   2,
						Stopped: 0,
						Failed:  0,
						Passed:  2,
					},
				},
				Failed: entity.MetricPoint{
					Frequency: entity.Frequency{Count: 1},
					Performance: entity.Performance{
						StdDev: 0,
						Avg:    3600,
						Median: 3600,
						Max:    3600,
						Min:    3600,
						P95:    3600,
					},
					Reliability: entity.Reliability{
						Total:   1,
						Stopped: 0,
						Failed:  1,
						Passed:  0,
					},
				},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := calculateMetricForRuns(tt.args.runs); !reflect.DeepEqual(got, tt.want) {
				t.Errorf("calculateMetricForRuns() = %v, want %v", got, tt.want)
			}
		})
	}
}

func createFakeRun(multiplier int, result string) entity.PipelineRun {
	return entity.PipelineRun{
		PipelineId:       uuid.New(),
		ProjectId:        uuid.New(),
		BranchId:         uuid.New(),
		BranchName:       "master",
		PipelineFileName: "file",
		Result:           result,
		Reason:           "TEST",
		RunningAt:        time.Now(),
		DoneAt:           time.Now().Add(time.Hour * time.Duration(multiplier)),
	}
}
