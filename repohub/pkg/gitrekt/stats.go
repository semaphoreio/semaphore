package gitrekt

import (
	"os"
	"path/filepath"
	"strings"
)

type Stats struct {
	TotalRepositoryCount  int
	TotalLockfileCount    int
	TotalQuarantinedCount int
	TotalUnknownCount     int
}

func GetStats() (*Stats, error) {
	files, err := os.ReadDir("/var/repos")
	if err != nil {
		return nil, err
	}

	info := &Stats{
		TotalRepositoryCount:  0,
		TotalLockfileCount:    0,
		TotalQuarantinedCount: 0,
		TotalUnknownCount:     0,
	}

	//
	// This algorithm has the assumption that every directory in /var/repos
	// is a repository.
	//
	// Lockfiles, and other meta-info are regular files.
	//
	for _, file := range files {
		if file.IsDir() {
			info.TotalRepositoryCount++
		} else if strings.HasSuffix(file.Name(), ".lock") {
			info.TotalLockfileCount++
		} else if strings.HasSuffix(file.Name(), ".quarantine") {
			info.TotalQuarantinedCount++
		} else {
			info.TotalUnknownCount++
		}
	}

	return info, nil
}

type QuarantineStats struct {
	QuarantineReasonAuthTimeout  int
	QuarantineReasonCloneTimeout int
	QuarantineReasonNotFound     int
	QuarantineReasonUnknown      int
}

func GetQuarantineStats() (*QuarantineStats, error) {
	files, err := filepath.Glob("/var/repos/*.quarantine")
	if err != nil {
		return nil, err
	}

	stats := &QuarantineStats{}

	for i := range files {
		f := files[i]
		f = filepath.Clean(f)
		content, err := os.ReadFile(f)
		if err != nil {
			stats.QuarantineReasonUnknown++
			continue
		}

		if strings.Contains(string(content), string(QuarantineReasonAuthTimeout)) {
			stats.QuarantineReasonAuthTimeout++
			continue
		}

		if strings.Contains(string(content), string(QuarantineReasonCloneTimeout)) {
			stats.QuarantineReasonCloneTimeout++
			continue
		}

		if strings.Contains(string(content), string(QuarantineReasonNotFound)) {
			stats.QuarantineReasonNotFound++
			continue
		}

		if strings.Contains(string(content), string(QuarantineReasonUnknown)) {
			stats.QuarantineReasonUnknown++
			continue
		}
	}

	return stats, nil
}
