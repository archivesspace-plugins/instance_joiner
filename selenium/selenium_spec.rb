if File.exist?(File.join( File.dirname(__FILE__), "../archivesspace"))
  require 'spec_helper'
else
  require '../../../selenium/spec/spec_helper'
end

describe "This should fail" do
  before(:all) do
    @repo = create(:repo, :repo_code => "rde_test_#{Time.now.to_i}")
    set_repo @repo

    @archivist_user = create_user(@repo => ['repository-archivists'])

    @driver = Driver.new.login_to_repo(@archivist_user, @repo)

    @resource = create(:resource)
    run_index_round
  end

  after(:all) do
    @driver.quit
  end
  
  it "should fail" do
    $driver.find_element_with_text('//div', /No way do i exist/)
  end


end
