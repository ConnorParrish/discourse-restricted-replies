# frozen_string_literal: true

# name: discourse-restricted-replies
# about: Restrict replies in certain categories to the OP and specified groups
# version: 1.0
# author: David Taylor
# url: https://github.com/discourse/discourse-restricted-replies

enabled_site_setting :restricted_replies_enabled

register_asset "stylesheets/restrict-replies.scss"

after_initialize do

  register_category_custom_field_type 'restrict_replies', :boolean
  register_category_custom_field_type 'restrict_replies_bypass_groups', [:integer]

  reloadable_patch do
    topic_overrides = Module.new do
      def can_create_post_on_topic?(topic)
        return super if !SiteSetting.restricted_replies_enabled
        return super if !topic&.category.custom_fields["restrict_replies"]
        default_value = super
        if default_value
          in_allowed_group = GroupUser.where(group_id: topic.category.custom_fields["restrict_replies_bypass_groups"], user_id: user.id).exists?
          return true if is_staff? || in_allowed_group || is_my_own?(topic)
        end
        false
      end
    end

    Guardian.class_exec do
      prepend topic_overrides
    end

    category_overrides = Module.new do
      def category_params
        return super if !SiteSetting.restricted_replies_enabled
        value = super
        value["custom_fields"]["restrict_replies_bypass_groups"] = params["custom_fields"]["restrict_replies_bypass_groups"]
        value
      end
    end

    CategoriesController.class_exec do
      prepend category_overrides
    end
  end
end