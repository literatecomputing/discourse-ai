#frozen_string_literal: true

class TestPersona < DiscourseAi::AiBot::Personas::Persona
  def commands
    [
      DiscourseAi::AiBot::Commands::TagsCommand,
      DiscourseAi::AiBot::Commands::SearchCommand,
      DiscourseAi::AiBot::Commands::ImageCommand,
    ]
  end

  def system_prompt
    <<~PROMPT
      {site_url}
      {site_title}
      {site_description}
      {participants}
      {time}

      {commands}
    PROMPT
  end
end

module DiscourseAi::AiBot::Personas
  RSpec.describe Persona do
    let :persona do
      TestPersona.new
    end

    let :topic_with_users do
      topic = Topic.new
      topic.allowed_users = [User.new(username: "joe"), User.new(username: "jane")]
      topic
    end

    fab!(:user) { Fabricate(:user) }

    it "can disable commands via constructor" do
      persona = TestPersona.new(allow_commands: false)

      rendered =
        persona.render_system_prompt(topic: topic_with_users, render_function_instructions: true)

      expect(rendered).not_to include("!tags")
      expect(rendered).not_to include("!search")

      expect(persona.available_functions).to be_empty
    end

    it "renders the system prompt" do
      freeze_time

      SiteSetting.title = "test site title"
      SiteSetting.site_description = "test site description"

      rendered =
        persona.render_system_prompt(topic: topic_with_users, render_function_instructions: true)

      expect(rendered).to include(Discourse.base_url)
      expect(rendered).to include("test site title")
      expect(rendered).to include("test site description")
      expect(rendered).to include("joe, jane")
      expect(rendered).to include(Time.zone.now.to_s)
      expect(rendered).to include("!search")
      expect(rendered).to include("!tags")
      # needs to be configured so it is not available
      expect(rendered).not_to include("!image")

      rendered =
        persona.render_system_prompt(topic: topic_with_users, render_function_instructions: false)

      expect(rendered).not_to include("!search")
      expect(rendered).not_to include("!tags")
    end

    describe "custom personas" do
      it "is able to find custom personas" do
        Group.refresh_automatic_groups!

        # define an ai persona everyone can see
        persona =
          AiPersona.create!(
            name: "pun_bot",
            description: "you write puns",
            system_prompt: "you are pun bot",
            commands: ["ImageCommand"],
            allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
          )

        custom_persona = DiscourseAi::AiBot::Personas.all(user: user).last
        expect(custom_persona.name).to eq("pun_bot")
        expect(custom_persona.description).to eq("you write puns")

        instance = custom_persona.new
        expect(instance.commands).to eq([DiscourseAi::AiBot::Commands::ImageCommand])
        expect(instance.render_system_prompt(render_function_instructions: true)).to eq(
          "you are pun bot",
        )

        # should update
        persona.update!(name: "pun_bot2")
        custom_persona = DiscourseAi::AiBot::Personas.all(user: user).last
        expect(custom_persona.name).to eq("pun_bot2")

        # can be disabled
        persona.update!(enabled: false)
        last_persona = DiscourseAi::AiBot::Personas.all(user: user).last
        expect(last_persona.name).not_to eq("pun_bot2")

        persona.update!(enabled: true)
        # no groups have access
        persona.update!(allowed_group_ids: [])

        last_persona = DiscourseAi::AiBot::Personas.all(user: user).last
        expect(last_persona.name).not_to eq("pun_bot2")
      end
    end

    describe "available personas" do
      it "includes all personas by default" do
        # must be enabled to see it
        SiteSetting.ai_stability_api_key = "abc"
        SiteSetting.ai_google_custom_search_api_key = "abc"

        expect(DiscourseAi::AiBot::Personas.all).to contain_exactly(
          General,
          SqlHelper,
          Artist,
          SettingsExplorer,
          Researcher,
          Creative,
          Mentor
        )
      end

      it "does not include personas that require api keys by default" do
        expect(DiscourseAi::AiBot::Personas.all).to contain_exactly(
          General,
          SqlHelper,
          SettingsExplorer,
          Creative,
        )
      end

      it "can be modified via site settings" do
        SiteSetting.ai_bot_enabled_personas = "general|sql_helper"

        expect(DiscourseAi::AiBot::Personas.all).to contain_exactly(General, SqlHelper)
      end
    end
  end
end
