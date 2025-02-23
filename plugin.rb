# frozen_string_literal: true

# name: discourse-ai
# about: Enables integration between AI modules and features in Discourse
# meta_topic_id: 259214
# version: 0.0.1
# authors: Discourse
# url: https://meta.discourse.org/t/discourse-ai/259214
# required_version: 2.7.0

gem "tokenizers", "0.3.3"
gem "tiktoken_ruby", "0.0.5"
gem "aws-eventstream", "1.2.0"

enabled_site_setting :discourse_ai_enabled

register_asset "stylesheets/modules/ai-helper/common/ai-helper.scss"

register_asset "stylesheets/modules/ai-bot/common/bot-replies.scss"

register_asset "stylesheets/modules/embeddings/common/semantic-related-topics.scss"
register_asset "stylesheets/modules/embeddings/common/semantic-search.scss"

register_asset "stylesheets/modules/sentiment/common/dashboard.scss"
register_asset "stylesheets/modules/sentiment/desktop/dashboard.scss", :desktop
register_asset "stylesheets/modules/sentiment/mobile/dashboard.scss", :mobile

module ::DiscourseAi
  PLUGIN_NAME = "discourse-ai"
end

require_relative "lib/discourse_ai/engine"

after_initialize do
  require_relative "lib/shared/inference/discourse_classifier"
  require_relative "lib/shared/inference/discourse_reranker"
  require_relative "lib/shared/inference/openai_completions"
  require_relative "lib/shared/inference/openai_embeddings"
  require_relative "lib/shared/inference/anthropic_completions"
  require_relative "lib/shared/inference/stability_generator"
  require_relative "lib/shared/inference/hugging_face_text_generation"
  require_relative "lib/shared/inference/amazon_bedrock_inference"
  require_relative "lib/shared/inference/cloudflare_workers_ai"
  require_relative "lib/shared/inference/function"
  require_relative "lib/shared/inference/function_list"

  require_relative "lib/shared/classificator"
  require_relative "lib/shared/post_classificator"
  require_relative "lib/shared/chat_message_classificator"

  require_relative "lib/shared/tokenizer/tokenizer"

  require_relative "lib/shared/database/connection"

  require_relative "lib/modules/nsfw/entry_point"
  require_relative "lib/modules/toxicity/entry_point"
  require_relative "lib/modules/sentiment/entry_point"
  require_relative "lib/modules/ai_helper/entry_point"
  require_relative "lib/modules/embeddings/entry_point"
  require_relative "lib/modules/summarization/entry_point"
  require_relative "lib/modules/ai_bot/entry_point"
  require_relative "lib/discourse_automation/llm_triage"

  [
    DiscourseAi::Embeddings::EntryPoint.new,
    DiscourseAi::NSFW::EntryPoint.new,
    DiscourseAi::Toxicity::EntryPoint.new,
    DiscourseAi::Sentiment::EntryPoint.new,
    DiscourseAi::AiHelper::EntryPoint.new,
    DiscourseAi::Summarization::EntryPoint.new,
    DiscourseAi::AiBot::EntryPoint.new,
  ].each do |a_module|
    a_module.load_files
    a_module.inject_into(self)
  end

  register_reviewable_type ReviewableAiChatMessage
  register_reviewable_type ReviewableAiPost

  on(:reviewable_transitioned_to) do |new_status, reviewable|
    ModelAccuracy.adjust_model_accuracy(new_status, reviewable)
  end
end
