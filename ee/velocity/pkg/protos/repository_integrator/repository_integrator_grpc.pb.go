// Code generated by protoc-gen-go-grpc. DO NOT EDIT.
// versions:
// - protoc-gen-go-grpc v1.3.0
// - protoc             v3.20.0
// source: repository_integrator.proto

package repository_integrator

import (
	context "context"
	empty "github.com/golang/protobuf/ptypes/empty"
	grpc "google.golang.org/grpc"
	codes "google.golang.org/grpc/codes"
	status "google.golang.org/grpc/status"
)

// This is a compile-time assertion to ensure that this generated file
// is compatible with the grpc package it is being compiled against.
// Requires gRPC-Go v1.32.0 or later.
const _ = grpc.SupportPackageIsVersion7

const (
	RepositoryIntegratorService_GetToken_FullMethodName               = "/InternalApi.RepositoryIntegrator.RepositoryIntegratorService/GetToken" // #nosec
	RepositoryIntegratorService_CheckToken_FullMethodName             = "/InternalApi.RepositoryIntegrator.RepositoryIntegratorService/CheckToken" // #nosec
	RepositoryIntegratorService_PreheatFileCache_FullMethodName       = "/InternalApi.RepositoryIntegrator.RepositoryIntegratorService/PreheatFileCache"
	RepositoryIntegratorService_GetFile_FullMethodName                = "/InternalApi.RepositoryIntegrator.RepositoryIntegratorService/GetFile"
	RepositoryIntegratorService_GithubInstallationInfo_FullMethodName = "/InternalApi.RepositoryIntegrator.RepositoryIntegratorService/GithubInstallationInfo"
	RepositoryIntegratorService_GetRepositories_FullMethodName        = "/InternalApi.RepositoryIntegrator.RepositoryIntegratorService/GetRepositories"
)

// RepositoryIntegratorServiceClient is the client API for RepositoryIntegratorService service.
//
// For semantics around ctx use and closing/ending streaming RPCs, please refer to https://pkg.go.dev/google.golang.org/grpc/?tab=doc#ClientConn.NewStream.
type RepositoryIntegratorServiceClient interface {
	GetToken(ctx context.Context, in *GetTokenRequest, opts ...grpc.CallOption) (*GetTokenResponse, error)
	CheckToken(ctx context.Context, in *CheckTokenRequest, opts ...grpc.CallOption) (*CheckTokenResponse, error)
	PreheatFileCache(ctx context.Context, in *PreheatFileCacheRequest, opts ...grpc.CallOption) (*empty.Empty, error)
	GetFile(ctx context.Context, in *GetFileRequest, opts ...grpc.CallOption) (*GetFileResponse, error)
	GithubInstallationInfo(ctx context.Context, in *GithubInstallationInfoRequest, opts ...grpc.CallOption) (*GithubInstallationInfoResponse, error)
	GetRepositories(ctx context.Context, in *GetRepositoriesRequest, opts ...grpc.CallOption) (*GetRepositoriesResponse, error)
}

type repositoryIntegratorServiceClient struct {
	cc grpc.ClientConnInterface
}

func NewRepositoryIntegratorServiceClient(cc grpc.ClientConnInterface) RepositoryIntegratorServiceClient {
	return &repositoryIntegratorServiceClient{cc}
}

func (c *repositoryIntegratorServiceClient) GetToken(ctx context.Context, in *GetTokenRequest, opts ...grpc.CallOption) (*GetTokenResponse, error) {
	out := new(GetTokenResponse)
	err := c.cc.Invoke(ctx, RepositoryIntegratorService_GetToken_FullMethodName, in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *repositoryIntegratorServiceClient) CheckToken(ctx context.Context, in *CheckTokenRequest, opts ...grpc.CallOption) (*CheckTokenResponse, error) {
	out := new(CheckTokenResponse)
	err := c.cc.Invoke(ctx, RepositoryIntegratorService_CheckToken_FullMethodName, in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *repositoryIntegratorServiceClient) PreheatFileCache(ctx context.Context, in *PreheatFileCacheRequest, opts ...grpc.CallOption) (*empty.Empty, error) {
	out := new(empty.Empty)
	err := c.cc.Invoke(ctx, RepositoryIntegratorService_PreheatFileCache_FullMethodName, in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *repositoryIntegratorServiceClient) GetFile(ctx context.Context, in *GetFileRequest, opts ...grpc.CallOption) (*GetFileResponse, error) {
	out := new(GetFileResponse)
	err := c.cc.Invoke(ctx, RepositoryIntegratorService_GetFile_FullMethodName, in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *repositoryIntegratorServiceClient) GithubInstallationInfo(ctx context.Context, in *GithubInstallationInfoRequest, opts ...grpc.CallOption) (*GithubInstallationInfoResponse, error) {
	out := new(GithubInstallationInfoResponse)
	err := c.cc.Invoke(ctx, RepositoryIntegratorService_GithubInstallationInfo_FullMethodName, in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (c *repositoryIntegratorServiceClient) GetRepositories(ctx context.Context, in *GetRepositoriesRequest, opts ...grpc.CallOption) (*GetRepositoriesResponse, error) {
	out := new(GetRepositoriesResponse)
	err := c.cc.Invoke(ctx, RepositoryIntegratorService_GetRepositories_FullMethodName, in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

// RepositoryIntegratorServiceServer is the server API for RepositoryIntegratorService service.
// All implementations should embed UnimplementedRepositoryIntegratorServiceServer
// for forward compatibility
type RepositoryIntegratorServiceServer interface {
	GetToken(context.Context, *GetTokenRequest) (*GetTokenResponse, error)
	CheckToken(context.Context, *CheckTokenRequest) (*CheckTokenResponse, error)
	PreheatFileCache(context.Context, *PreheatFileCacheRequest) (*empty.Empty, error)
	GetFile(context.Context, *GetFileRequest) (*GetFileResponse, error)
	GithubInstallationInfo(context.Context, *GithubInstallationInfoRequest) (*GithubInstallationInfoResponse, error)
	GetRepositories(context.Context, *GetRepositoriesRequest) (*GetRepositoriesResponse, error)
}

// UnimplementedRepositoryIntegratorServiceServer should be embedded to have forward compatible implementations.
type UnimplementedRepositoryIntegratorServiceServer struct {
}

func (UnimplementedRepositoryIntegratorServiceServer) GetToken(context.Context, *GetTokenRequest) (*GetTokenResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "method GetToken not implemented")
}
func (UnimplementedRepositoryIntegratorServiceServer) CheckToken(context.Context, *CheckTokenRequest) (*CheckTokenResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "method CheckToken not implemented")
}
func (UnimplementedRepositoryIntegratorServiceServer) PreheatFileCache(context.Context, *PreheatFileCacheRequest) (*empty.Empty, error) {
	return nil, status.Errorf(codes.Unimplemented, "method PreheatFileCache not implemented")
}
func (UnimplementedRepositoryIntegratorServiceServer) GetFile(context.Context, *GetFileRequest) (*GetFileResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "method GetFile not implemented")
}
func (UnimplementedRepositoryIntegratorServiceServer) GithubInstallationInfo(context.Context, *GithubInstallationInfoRequest) (*GithubInstallationInfoResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "method GithubInstallationInfo not implemented")
}
func (UnimplementedRepositoryIntegratorServiceServer) GetRepositories(context.Context, *GetRepositoriesRequest) (*GetRepositoriesResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "method GetRepositories not implemented")
}

// UnsafeRepositoryIntegratorServiceServer may be embedded to opt out of forward compatibility for this service.
// Use of this interface is not recommended, as added methods to RepositoryIntegratorServiceServer will
// result in compilation errors.
type UnsafeRepositoryIntegratorServiceServer interface {
	mustEmbedUnimplementedRepositoryIntegratorServiceServer()
}

func RegisterRepositoryIntegratorServiceServer(s grpc.ServiceRegistrar, srv RepositoryIntegratorServiceServer) {
	s.RegisterService(&RepositoryIntegratorService_ServiceDesc, srv)
}

func _RepositoryIntegratorService_GetToken_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(GetTokenRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(RepositoryIntegratorServiceServer).GetToken(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: RepositoryIntegratorService_GetToken_FullMethodName,
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(RepositoryIntegratorServiceServer).GetToken(ctx, req.(*GetTokenRequest))
	}
	return interceptor(ctx, in, info, handler)
}

func _RepositoryIntegratorService_CheckToken_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(CheckTokenRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(RepositoryIntegratorServiceServer).CheckToken(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: RepositoryIntegratorService_CheckToken_FullMethodName,
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(RepositoryIntegratorServiceServer).CheckToken(ctx, req.(*CheckTokenRequest))
	}
	return interceptor(ctx, in, info, handler)
}

func _RepositoryIntegratorService_PreheatFileCache_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(PreheatFileCacheRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(RepositoryIntegratorServiceServer).PreheatFileCache(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: RepositoryIntegratorService_PreheatFileCache_FullMethodName,
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(RepositoryIntegratorServiceServer).PreheatFileCache(ctx, req.(*PreheatFileCacheRequest))
	}
	return interceptor(ctx, in, info, handler)
}

func _RepositoryIntegratorService_GetFile_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(GetFileRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(RepositoryIntegratorServiceServer).GetFile(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: RepositoryIntegratorService_GetFile_FullMethodName,
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(RepositoryIntegratorServiceServer).GetFile(ctx, req.(*GetFileRequest))
	}
	return interceptor(ctx, in, info, handler)
}

func _RepositoryIntegratorService_GithubInstallationInfo_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(GithubInstallationInfoRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(RepositoryIntegratorServiceServer).GithubInstallationInfo(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: RepositoryIntegratorService_GithubInstallationInfo_FullMethodName,
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(RepositoryIntegratorServiceServer).GithubInstallationInfo(ctx, req.(*GithubInstallationInfoRequest))
	}
	return interceptor(ctx, in, info, handler)
}

func _RepositoryIntegratorService_GetRepositories_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(GetRepositoriesRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(RepositoryIntegratorServiceServer).GetRepositories(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: RepositoryIntegratorService_GetRepositories_FullMethodName,
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(RepositoryIntegratorServiceServer).GetRepositories(ctx, req.(*GetRepositoriesRequest))
	}
	return interceptor(ctx, in, info, handler)
}

// RepositoryIntegratorService_ServiceDesc is the grpc.ServiceDesc for RepositoryIntegratorService service.
// It's only intended for direct use with grpc.RegisterService,
// and not to be introspected or modified (even as a copy)
var RepositoryIntegratorService_ServiceDesc = grpc.ServiceDesc{
	ServiceName: "InternalApi.RepositoryIntegrator.RepositoryIntegratorService",
	HandlerType: (*RepositoryIntegratorServiceServer)(nil),
	Methods: []grpc.MethodDesc{
		{
			MethodName: "GetToken",
			Handler:    _RepositoryIntegratorService_GetToken_Handler,
		},
		{
			MethodName: "CheckToken",
			Handler:    _RepositoryIntegratorService_CheckToken_Handler,
		},
		{
			MethodName: "PreheatFileCache",
			Handler:    _RepositoryIntegratorService_PreheatFileCache_Handler,
		},
		{
			MethodName: "GetFile",
			Handler:    _RepositoryIntegratorService_GetFile_Handler,
		},
		{
			MethodName: "GithubInstallationInfo",
			Handler:    _RepositoryIntegratorService_GithubInstallationInfo_Handler,
		},
		{
			MethodName: "GetRepositories",
			Handler:    _RepositoryIntegratorService_GetRepositories_Handler,
		},
	},
	Streams:  []grpc.StreamDesc{},
	Metadata: "repository_integrator.proto",
}
