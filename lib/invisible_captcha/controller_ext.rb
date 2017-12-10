module InvisibleCaptcha
  module ControllerExt
    module ClassMethods
      def invisible_captcha(options = {})
        if respond_to?(:before_action)
          before_action(options) do
            detect_spam(options)
          end
        else
          before_filter(options) do
            detect_spam(options)
          end
        end
      end
    end

    def detect_spam(options = {})
      if timestamp_spam?(options)
        on_timestamp_spam(options)
      elsif honeypot_spam?(options)
        on_spam(options)
      end
    end

    def on_timestamp_spam(options = {})
      if action = options[:on_timestamp_spam]
        send(action)
      else
        if respond_to?(:redirect_back)
          redirect_back(fallback_location: root_path, flash: { error: InvisibleCaptcha.timestamp_error_message })
        else
          redirect_to :back, flash: { error: InvisibleCaptcha.timestamp_error_message }
        end
      end
    end

    def on_spam(options = {})
      if action = options[:on_spam]
        send(action)
      else
        head(200)
      end
    end

    def timestamp_spam?(options = {})
      enabled = if options.key?(:timestamp_enabled)
        options[:timestamp_enabled]
      else
        InvisibleCaptcha.timestamp_enabled
      end

      return false unless enabled

      timestamp = session[:invisible_captcha_timestamp]

      # Consider as spam if timestamp not in session, cause that means the form was not fetched at all
      unless timestamp
        logger.warn("Potential spam detected for IP #{request.env['REMOTE_ADDR']}. Invisible Captcha timestamp not found in session.")
        return true
      end

      time_to_submit = Time.zone.now - DateTime.iso8601(timestamp)
      threshold = options[:timestamp_threshold] || InvisibleCaptcha.timestamp_threshold

      # Consider as spam if form submitted too quickly
      if time_to_submit < threshold
        logger.warn("Potential spam detected for IP #{request.env['REMOTE_ADDR']}. Invisible Captcha timestamp threshold not reached (took #{time_to_submit.to_i}s).")
        return true
      end
      false
    end

    def honeypot_spam?(options = {})
      honeypot = options[:honeypot]
      scope    = options[:scope] || controller_name.singularize

      if honeypot
        # If honeypot is presented, search for:
        # - honeypot: params[:subtitle]
        # - honeypot with scope: params[:topic][:subtitle]
        if params[honeypot].present? || (params[scope] && params[scope][honeypot].present?)
          return true
        end
      else
        InvisibleCaptcha.honeypots.each do |field|
          return true if params[field].present?
        end
      end
      false
    end
  end
end
