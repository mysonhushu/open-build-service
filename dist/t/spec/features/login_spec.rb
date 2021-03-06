require "spec_helper"
#for getting spec file
require 'tmpdir'
require "net/https"
require "uri"

RSpec.describe "Sign Up & Login" do
  it "should be able to sign up successfully and logout" do
    visit "/"
    expect(page).to have_content("Log In")
    fill_in 'login', with: 'test_user'
    fill_in 'email', with: 'test_user@openqa.com'
    fill_in 'pwd', with: 'opensuse'
    click_button('Sign Up')
    expect(page).to have_content("The account 'test_user' is now active.")
    within("div#subheader") do
      click_link('Logout')
    end
  end
end

RSpec.describe "Create Interconnect as admin and build pckg" do
  it "should be able to add Opensuse Interconnect as Admin" do
    visit "/user/login"
    fill_in 'user_login', with: 'Admin'
    fill_in 'user_password', with: 'opensuse'
    click_button('Log In »')
    visit "/configuration/interconnect"
    click_button('openSUSE')
    click_button('Save changes')
  end

  it "should be able to create home project" do
    click_link('Create Home')
    expect(page).to have_content("Create New Project")
    find('input[name="commit"]').click #Create Project
    expect(page).to have_content("Project 'home:Admin' was created successfully")
  end

  it "should be able to create a new package from OBS:Server:Unstable/build/build.spec and _service files" do
    dir = Dir.mktmpdir
    File.write("#{dir}/build.spec", Net::HTTP.get(URI.parse("https://api.opensuse.org/public/source/OBS:Server:Unstable/build/build.spec")))
    find('img[title="Create package"]').click
    expect(page).to have_content("Create New Package for home:Admin")
    fill_in 'name', with: 'obs-build'
    find('input[name="commit"]').click #Save changes
    expect(page).to have_content("Package 'obs-build' was created successfully")
    find('img[title="Add file"]').click
    expect(page).to have_content("Add File to")
    attach_file("file", "#{dir}/build.spec")
    find('input[name="commit"]').click #Save changes
    expect(page).to have_content("Source Files")
    File.write("#{dir}/_service", Net::HTTP.get(URI.parse("https://api.opensuse.org/public/source/OBS:Server:Unstable/build/_service")))
    find('img[title="Add file"]').click
    expect(page).to have_content("Add File to")
    attach_file("file", "#{dir}/_service")
    find('input[name="commit"]').click #Save changes
    expect(page).to have_content("Source Files")
  end

  it "should be able to add build targets from existing repos" do
    click_link('build targets')
    expect(page).to have_content("openSUSE distributions")
    check('repo_openSUSE_Tumbleweed')
    check('repo_openSUSE_Leap_42.1')
    find('input[id="submitrepos"]').click #Add selected repositories
    expect(page).to have_content("Successfully added repositories")
    expect(page).to have_content("openSUSE_Leap_42.1 (x86_64)")
    expect(page).to have_content("openSUSE_Tumbleweed (i586, x86_64)")
  end

  it "should be able to Overview Build Results" do
    click_link('Overview')
    expect(page).to have_content("Build Results")
  end

  it "should be able to check Build Results and see succeeded package built" do
    sleep(10)
    visit "/package/live_build_log/home:Admin/obs-build/openSUSE_Tumbleweed/i586"
    begin
      Timeout.timeout(160) {
        if page.has_content?("No live log available:") then
          page.evaluate_script("window.location.reload()")
          first(:link, "Start refresh").click
        end
        expect(page).to have_selector("div#log_space_wrapper", :wait => 20)
        expect(page).to have_content('finished "build build.spec"', :wait => 160)
      }
    rescue Timeout::Error
      page.evaluate_script("window.location.reload()")
      expect(page).to have_content('finished "build build.spec"', :wait => 120)
    end
    visit "/package/live_build_log/home:Admin/obs-build/openSUSE_Leap_42.1/x86_64"
    begin
      Timeout.timeout(90) {
        expect(page).to have_selector("div#log_space_wrapper", :wait => 20)
        page.evaluate_script("window.location.reload()") if page.has_content?("No live log available:")
        next if page.has_content?("Build finished")
        expect(page).to have_content('finished "build build.spec"', :wait => 90)
      }
    rescue Timeout::Error
      page.evaluate_script("window.location.reload()")
      next if page.has_content?("Build finished")
      expect(page).to have_content('finished "build build.spec"', :wait => 60)
    end
    visit "/project/show/home:Admin/"
    expect(page).to have_content("Build Results")
    click_link("Build Results")
    retries = 30
    while (page.has_no_content?("succeeded: 1", :count => 3, :wait => 1)) && retries > 0 do
      page.evaluate_script("window.location.reload()")
      sleep(5)
      puts "Refreshed Build Results @ #{Time.now}.\nCurrent status: \n"
      puts "#{find("div#project_buildstatus").text}"
      retries -= 1
    end
  end
end
