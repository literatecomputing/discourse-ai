# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module HydeGenerators
      class OpenAi < DiscourseAi::Embeddings::HydeGenerators::Base
        def prompt(search_term)
          [
            {
              role: "system",
              content: "You are a helpful bot. You create forum posts about a given subject.",
            },
            { role: "user", content: "#{basic_prompt_instruction}\n#{search_term}" },
          ]
        end

        def models
          %w[gpt-3.5-turbo gpt-4]
        end

        def hypothetical_post_from(query)
          ::DiscourseAi::Inference::OpenAiCompletions.perform!(
            prompt(query),
            SiteSetting.ai_embeddings_semantic_search_hyde_model,
            max_tokens: 400,
          ).dig(:choices, 0, :message, :content)
        end
      end
    end
  end
end
