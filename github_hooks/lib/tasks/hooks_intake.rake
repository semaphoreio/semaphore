namespace :hooks do
  desc "Verify and record GitHub hooks taken from the RabbitMQ intake queue"
  task :intake => :environment do
    Semaphore::RepoHost::Hooks::Intake::Consumer.new.run
  end
end
