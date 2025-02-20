require "spec_helper"

RSpec.describe Exceptions do

  let(:logger) { Rails.logger }

  def standard_exception
    Exceptions.handle_worker_exceptions(logger) do
      raise "test exception"
    end
  end

  def fatal_postgres_exception
    Exceptions.handle_worker_exceptions(logger) do

      raise PG::UnableToSend, "PG died"
    rescue PG::UnableToSend
      raise ActiveRecord::StatementInvalid, "PG died"

    end
  end

  def non_fatal_postgres_exception
    Exceptions.handle_worker_exceptions(logger) do

      raise PG::InvalidResultStatus, "PG died"
    rescue PG::InvalidResultStatus
      raise ActiveRecord::StatementInvalid, "PG died"

    end
  end

  describe ".notify" do
    context "argument is a string" do
      it "records without raising an exception" do
        expect { Exceptions.notify("darth vader") }.not_to raise_exception
      end
    end

    context "argument is an exception" do
      it "records without raising an exception" do
        expect { Exceptions.notify(Exception.new("darth vader")) }.not_to raise_exception
      end
    end
  end
end
