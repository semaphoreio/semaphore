namespace :app do
  namespace :grpc do
    require "grpc/health/checker"

    task :branch_api => :environment do
      start_grpc_server("Branch API", InternalApi::Branch::BranchServer.new)
    end

    task :authentication_api => :environment do
      start_grpc_server("Authentication API", InternalApi::Auth::AuthenticationService.new)
    end

    task :project_api => :environment do
      start_grpc_server("Project API", InternalApi::Project::ProjectServer.new)
    end

    task :repo_proxy_api => :environment do
      start_grpc_server("RepoProxy API", [InternalApi::RepoProxy::RepoProxyServer.new, InternalApi::RepositoryIntegrator::RepositoryIntegratorServer.new])
    end

    task :user_api => :environment do
      start_grpc_server("User API", InternalApi::User::UserServer.new)
    end

    task :projecthub => :environment do
      start_grpc_server("ProjectHub", InternalApi::Projecthub::Server.new)
    end

    task :organization_api => :environment do
      start_grpc_server("Organization API", InternalApi::Organization::OrganizationServer.new)
    end

    task :workflow_ctrl => :environment do
      start_grpc_server("Workflow CTRL", InternalApi::Wf::Server.new)
    end

    task :public_workflows_v1alpha => :environment do
      start_grpc_server("Public Workflow V1alpha", PublicApi::Workflow::V1alpha::Server.new)
    end

    def start_grpc_server(name, handlers)
      grpc_port    = ENV.fetch("GRPC_PORT", "50051")
      grpc_host    = ENV.fetch("GRPC_HOST", "0.0.0.0")
      grpc_workers = ENV.fetch("GRPC_WORKERS", "200").to_i

      server = GRPC::RpcServer.new(:pool_size => grpc_workers)
      address = "#{grpc_host}:#{grpc_port}"
      server.add_http2_port(address, :this_port_is_insecure)

      puts "Started #{name} GRPC server on #{address} with #{grpc_workers} workers."

      Array(handlers).each do |handler|
        server.handle(handler)
      end

      health_checker = Grpc::Health::Checker.new
      health_checker.add_status(
        name,
        Grpc::Health::V1::HealthCheckResponse::ServingStatus::SERVING
      )
      server.handle(health_checker)

      server.run_till_terminated
    end
  end
end
