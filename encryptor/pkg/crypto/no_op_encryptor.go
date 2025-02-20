package crypto

type NoOpEncryptor struct {
}

func NewNoOpEncryptor() (Encryptor, error) {
	return &NoOpEncryptor{}, nil
}

func (e *NoOpEncryptor) Encrypt(data []byte, associatedData []byte) ([]byte, error) {
	return data, nil
}

func (e *NoOpEncryptor) Decrypt(cypher []byte, associatedData []byte) ([]byte, error) {
	return cypher, nil
}
