RSpec.describe YoutubeRb do
  it "has a version number" do
    expect(YoutubeRb::VERSION).not_to be nil
  end

  it "creates a client instance" do
    client = YoutubeRb::Client.new(api_key: "test_key")
    expect(client).to be_a(YoutubeRb::Client)
  end
end
