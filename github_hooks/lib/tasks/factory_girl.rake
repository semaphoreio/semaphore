namespace :factory_girl do
  desc "Verify that all FactoryBot factories are valid"
  task :lint => :environment do
    if Rails.env.test?
      begin
        DatabaseCleaner.start
        Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

        FactoryBot.lint
      ensure
        DatabaseCleaner.clean
      end
    else
      system("bundle exec rake factory_girl:lint RAILS_ENV='test'")
    end
  end
end
