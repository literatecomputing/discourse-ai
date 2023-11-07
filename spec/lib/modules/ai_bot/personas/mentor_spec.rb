# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Personas::Mentor do
  let :mentor do
    subject
  end

  it "renders schema" do
    expect(mentor.commands).to eq([DiscourseAi::AiBot::Commands::GoogleCommand])
  end
end
