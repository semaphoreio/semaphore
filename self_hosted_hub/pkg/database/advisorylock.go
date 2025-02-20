package database

import (
	"context"

	log "github.com/sirupsen/logrus"
	gorm "gorm.io/gorm"
)

func WithBlockingAdvisoryLock(ctx context.Context, lockID string, lockFunc func(tx *gorm.DB) error) (err error) {
	// Using a context here gives the caller the ability
	// to use timeouts and not block forever waiting for the lock.
	tx := Conn().WithContext(ctx).Begin()

	defer func() {
		if p := recover(); p != nil {
			tx.Rollback()
			panic(p) // re-throw panic after Rollback
		} else if err != nil {
			tx.Rollback() // err is non-nil; don't change it
		} else {
			err = tx.Commit().Error // err is nil; if Commit returns error update err
		}
	}()

	// This will block until all other transactions
	// that acquired the lock release it.
	err = tx.Exec("SELECT pg_advisory_xact_lock(hashtext(?))", lockID).Error
	if err != nil {
		log.Infof("Error acquiring lock %s: %v\n", lockID, err)
		return err
	}

	// Lock was acquired, execute function
	return lockFunc(tx)
}

func WithAdvisoryLock(lockID string, lockFunc func(tx *gorm.DB) error) (err error) {
	tx := Conn().Begin()

	defer func() {
		if p := recover(); p != nil {
			tx.Rollback()
			panic(p) // re-throw panic after Rollback
		} else if err != nil {
			tx.Rollback() // err is non-nil; don't change it
		} else {
			err = tx.Commit().Error // err is nil; if Commit returns error update err
		}
	}()

	lock := false

	err = tx.Raw("SELECT pg_try_advisory_xact_lock(hashtext(?))", lockID).Row().Scan(&lock)

	if err != nil {
		return err
	}

	if lock {
		// lock acquired, process
		return lockFunc(tx)
	}

	// no lock do nothing
	return nil
}
