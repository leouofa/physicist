# frozen_string_literal: true

require "test_helper"

class ParticleGroupsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulateParticleGroupsJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulateParticleGroupsJob) do
      post populate_particle_groups_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Particle Groups...", response.body
  end

  test "populate enqueues PopulateParticleGroupsJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulateParticleGroupsJob) do
      post populate_particle_groups_url
    end

    assert_redirected_to root_url
  end
end
