package api

import (
	"context"
	"fmt"

	crypto "github.com/semaphoreio/semaphore/encryptor/pkg/crypto"
	pb "github.com/semaphoreio/semaphore/encryptor/pkg/protos/encryptor"
)

type EncryptorService struct {
	Encryptor crypto.Encryptor
}

func NewEncryptorService(encryptor crypto.Encryptor) *EncryptorService {
	return &EncryptorService{Encryptor: encryptor}
}

func (s *EncryptorService) Encrypt(ctx context.Context, request *pb.EncryptRequest) (*pb.EncryptResponse, error) {
	cypherText, err := s.Encryptor.Encrypt(request.Raw, request.AssociatedData)
	if err != nil {
		return nil, fmt.Errorf("encryption error: %v", err)
	}

	return &pb.EncryptResponse{Cypher: cypherText}, nil
}

func (s *EncryptorService) Decrypt(ctx context.Context, request *pb.DecryptRequest) (*pb.DecryptResponse, error) {
	raw, err := s.Encryptor.Decrypt(request.Cypher, request.AssociatedData)
	if err != nil {
		return nil, fmt.Errorf("decrypting error: %v", err)
	}

	return &pb.DecryptResponse{Raw: raw}, nil
}
