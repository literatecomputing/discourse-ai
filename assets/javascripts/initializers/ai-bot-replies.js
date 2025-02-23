import { hbs } from "ember-cli-htmlbars";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import loadScript from "discourse/lib/load-script";
import { withPluginApi } from "discourse/lib/plugin-api";
import { cook } from "discourse/lib/text";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";
import { composeAiBotMessage } from "discourse/plugins/discourse-ai/discourse/lib/ai-bot-helper";

function isGPTBot(user) {
  return user && [-110, -111, -112].includes(user.id);
}

function attachHeaderIcon(api) {
  const settings = api.container.lookup("service:site-settings");

  const enabledBots = settings.ai_bot_add_to_header
    ? settings.ai_bot_enabled_chat_bots.split("|").filter(Boolean)
    : [];
  if (enabledBots.length > 0) {
    api.attachWidgetAction("header", "showAiBotPanel", function () {
      this.state.botSelectorVisible = true;
    });

    api.attachWidgetAction("header", "hideAiBotPanel", function () {
      this.state.botSelectorVisible = false;
    });

    api.decorateWidget("header-icons:before", (helper) => {
      return helper.attach("header-dropdown", {
        title: "discourse_ai.ai_bot.shortcut_title",
        icon: "robot",
        action: "clickStartAiBotChat",
        active: false,
        classNames: ["ai-bot-button"],
      });
    });

    if (enabledBots.length === 1) {
      api.attachWidgetAction("header", "clickStartAiBotChat", function () {
        composeAiBotMessage(
          enabledBots[0],
          api.container.lookup("service:composer")
        );
      });
    } else {
      api.attachWidgetAction("header", "clickStartAiBotChat", function () {
        this.sendWidgetAction("showAiBotPanel");
      });
    }

    api.addHeaderPanel(
      "ai-bot-header-panel-wrapper",
      "botSelectorVisible",
      function () {
        return {};
      }
    );
  }
}

function initializeAIBotReplies(api) {
  api.addPostMenuButton("cancel-gpt", (post) => {
    if (isGPTBot(post.user)) {
      return {
        icon: "pause",
        action: "cancelStreaming",
        title: "discourse_ai.ai_bot.cancel_streaming",
        className: "btn btn-default cancel-streaming",
        position: "first",
      };
    }
  });

  api.attachWidgetAction("post", "cancelStreaming", function () {
    ajax(`/discourse-ai/ai-bot/post/${this.model.id}/stop-streaming`, {
      type: "POST",
    })
      .then(() => {
        document
          .querySelector(`#post_${this.model.post_number}`)
          .classList.remove("streaming");
      })
      .catch(popupAjaxError);
  });

  api.modifyClass("controller:topic", {
    pluginId: "discourse-ai",

    onAIBotStreamedReply: function (data) {
      const post = this.model.postStream.findLoadedPost(data.post_id);

      if (post) {
        if (data.raw) {
          cook(data.raw).then((cooked) => {
            post.set("raw", data.raw);
            post.set("cooked", cooked);

            document
              .querySelector(`#post_${data.post_number}`)
              .classList.add("streaming");

            const cookedElement = document.createElement("div");
            cookedElement.innerHTML = cooked;

            let element = document.querySelector(
              `#post_${data.post_number} .cooked`
            );

            loadScript("/javascripts/diffhtml.min.js").then(() => {
              window.diff.innerHTML(element, cookedElement.innerHTML);
            });
          });
        }
        if (data.done) {
          document
            .querySelector(`#post_${data.post_number}`)
            .classList.remove("streaming");
        }
      }
    },
    subscribe: function () {
      this._super();

      if (
        this.model.isPrivateMessage &&
        this.model.details.allowed_users &&
        this.model.details.allowed_users.filter(isGPTBot).length >= 1
      ) {
        this.messageBus.subscribe(
          `discourse-ai/ai-bot/topic/${this.model.id}`,
          this.onAIBotStreamedReply.bind(this)
        );
      }
    },
    unsubscribe: function () {
      this.messageBus.unsubscribe("discourse-ai/ai-bot/topic/*");
      this._super();
    },
  });
}

function initializePersonaDecorator(api) {
  let topicController = null;
  api.decorateWidget(`poster-name:after`, (dec) => {
    if (!isGPTBot(dec.attrs.user)) {
      return;
    }
    // this is hacky and will need to change
    // trouble is we need to get the model for the topic
    // and it is not available in the decorator
    // long term this will not be a problem once we remove widgets and
    // have a saner structure for our model
    topicController =
      topicController || api.container.lookup("controller:topic");

    return dec.widget.attach("persona-flair", {
      topicController,
    });
  });

  registerWidgetShim(
    "persona-flair",
    "span.persona-flair",
    hbs`{{@data.topicController.model.ai_persona_name}}`
  );
}

export default {
  name: "discourse-ai-bot-replies",

  initialize(container) {
    const settings = container.lookup("service:site-settings");
    const user = container.lookup("service:current-user");

    if (user?.ai_enabled_chat_bots) {
      if (settings.ai_bot_add_to_header) {
        withPluginApi("1.6.0", attachHeaderIcon);
      }
      withPluginApi("1.6.0", initializeAIBotReplies);
      withPluginApi("1.6.0", initializePersonaDecorator);
    }
  },
};
