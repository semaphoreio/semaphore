# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: repository_integrator.proto

require 'google/protobuf'

require_relative 'google/protobuf/timestamp_pb'
require_relative 'google/protobuf/empty_pb'


descriptor_data = "\n\x1brepository_integrator.proto\x12 InternalApi.RepositoryIntegrator\x1a\x1fgoogle/protobuf/timestamp.proto\x1a\x1bgoogle/protobuf/empty.proto\"\x9c\x01\n\x0fGetTokenRequest\x12\x0f\n\x07user_id\x18\x01 \x01(\t\x12\x17\n\x0frepository_slug\x18\x02 \x01(\t\x12K\n\x10integration_type\x18\x03 \x01(\x0e\x32\x31.InternalApi.RepositoryIntegrator.IntegrationType\x12\x12\n\nproject_id\x18\x04 \x01(\t\"Q\n\x10GetTokenResponse\x12\r\n\x05token\x18\x01 \x01(\t\x12.\n\nexpires_at\x18\x02 \x01(\x0b\x32\x1a.google.protobuf.Timestamp\"\'\n\x11\x43heckTokenRequest\x12\x12\n\nproject_id\x18\x01 \x01(\t\"r\n\x12\x43heckTokenResponse\x12\r\n\x05valid\x18\x01 \x01(\x08\x12M\n\x11integration_scope\x18\x02 \x01(\x0e\x32\x32.InternalApi.RepositoryIntegrator.IntegrationScope\"H\n\x17PreheatFileCacheRequest\x12\x12\n\nproject_id\x18\x01 \x01(\t\x12\x0c\n\x04path\x18\x02 \x01(\t\x12\x0b\n\x03ref\x18\x03 \x01(\t\"?\n\x0eGetFileRequest\x12\x12\n\nproject_id\x18\x01 \x01(\t\x12\x0c\n\x04path\x18\x02 \x01(\t\x12\x0b\n\x03ref\x18\x03 \x01(\t\"\"\n\x0fGetFileResponse\x12\x0f\n\x07\x63ontent\x18\x01 \x01(\t\"3\n\x1dGithubInstallationInfoRequest\x12\x12\n\nproject_id\x18\x01 \x01(\t\"l\n\x1eGithubInstallationInfoResponse\x12\x17\n\x0finstallation_id\x18\x01 \x01(\x03\x12\x17\n\x0f\x61pplication_url\x18\x02 \x01(\t\x12\x18\n\x10installation_url\x18\x03 \x01(\t\"\x1f\n\x1dInitGithubInstallationRequest\" \n\x1eInitGithubInstallationResponse\"v\n\x16GetRepositoriesRequest\x12\x0f\n\x07user_id\x18\x01 \x01(\t\x12K\n\x10integration_type\x18\x02 \x01(\x0e\x32\x31.InternalApi.RepositoryIntegrator.IntegrationType\"]\n\x17GetRepositoriesResponse\x12\x42\n\x0crepositories\x18\x01 \x03(\x0b\x32,.InternalApi.RepositoryIntegrator.Repository\"`\n\nRepository\x12\x0f\n\x07\x61\x64\x64\x61\x62le\x18\x01 \x01(\x08\x12\x0c\n\x04name\x18\x02 \x01(\t\x12\x11\n\tfull_name\x18\x04 \x01(\t\x12\x0b\n\x03url\x18\x03 \x01(\t\x12\x13\n\x0b\x64\x65scription\x18\x05 \x01(\t*]\n\x0fIntegrationType\x12\x16\n\x12GITHUB_OAUTH_TOKEN\x10\x00\x12\x0e\n\nGITHUB_APP\x10\x01\x12\r\n\tBITBUCKET\x10\x02\x12\n\n\x06GITLAB\x10\x03\x12\x07\n\x03GIT\x10\x04*K\n\x10IntegrationScope\x12\x13\n\x0f\x46ULL_CONNECTION\x10\x00\x12\x0f\n\x0bONLY_PUBLIC\x10\x01\x12\x11\n\rNO_CONNECTION\x10\x02\x32\xa5\x07\n\x1bRepositoryIntegratorService\x12q\n\x08GetToken\x12\x31.InternalApi.RepositoryIntegrator.GetTokenRequest\x1a\x32.InternalApi.RepositoryIntegrator.GetTokenResponse\x12w\n\nCheckToken\x12\x33.InternalApi.RepositoryIntegrator.CheckTokenRequest\x1a\x34.InternalApi.RepositoryIntegrator.CheckTokenResponse\x12\x65\n\x10PreheatFileCache\x12\x39.InternalApi.RepositoryIntegrator.PreheatFileCacheRequest\x1a\x16.google.protobuf.Empty\x12n\n\x07GetFile\x12\x30.InternalApi.RepositoryIntegrator.GetFileRequest\x1a\x31.InternalApi.RepositoryIntegrator.GetFileResponse\x12\x9b\x01\n\x16GithubInstallationInfo\x12?.InternalApi.RepositoryIntegrator.GithubInstallationInfoRequest\x1a@.InternalApi.RepositoryIntegrator.GithubInstallationInfoResponse\x12\x9b\x01\n\x16InitGithubInstallation\x12?.InternalApi.RepositoryIntegrator.InitGithubInstallationRequest\x1a@.InternalApi.RepositoryIntegrator.InitGithubInstallationResponse\x12\x86\x01\n\x0fGetRepositories\x12\x38.InternalApi.RepositoryIntegrator.GetRepositoriesRequest\x1a\x39.InternalApi.RepositoryIntegrator.GetRepositoriesResponseb\x06proto3"

pool = Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module InternalApi
  module RepositoryIntegrator
    GetTokenRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.RepositoryIntegrator.GetTokenRequest").msgclass
    GetTokenResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.RepositoryIntegrator.GetTokenResponse").msgclass
    CheckTokenRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.RepositoryIntegrator.CheckTokenRequest").msgclass
    CheckTokenResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.RepositoryIntegrator.CheckTokenResponse").msgclass
    PreheatFileCacheRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.RepositoryIntegrator.PreheatFileCacheRequest").msgclass
    GetFileRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.RepositoryIntegrator.GetFileRequest").msgclass
    GetFileResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.RepositoryIntegrator.GetFileResponse").msgclass
    GithubInstallationInfoRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.RepositoryIntegrator.GithubInstallationInfoRequest").msgclass
    GithubInstallationInfoResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.RepositoryIntegrator.GithubInstallationInfoResponse").msgclass
    InitGithubInstallationRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.RepositoryIntegrator.InitGithubInstallationRequest").msgclass
    InitGithubInstallationResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.RepositoryIntegrator.InitGithubInstallationResponse").msgclass
    GetRepositoriesRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.RepositoryIntegrator.GetRepositoriesRequest").msgclass
    GetRepositoriesResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.RepositoryIntegrator.GetRepositoriesResponse").msgclass
    Repository = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.RepositoryIntegrator.Repository").msgclass
    IntegrationType = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.RepositoryIntegrator.IntegrationType").enummodule
    IntegrationScope = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.RepositoryIntegrator.IntegrationScope").enummodule
  end
end
