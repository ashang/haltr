# encoding: utf-8
module Haltr::ExportableDocument

  def self.included(base)
    base.class_eval do

      attr_accessor :export_errors

      after_initialize do |obj|
        obj.export_errors ||= []
      end

      def can_be_exported?(channel=nil)
        channel ||= self.client.invoice_format rescue nil
        channel = channel.to_s
        # TODO Test if endpoint is correcty configured
        return @can_be_exported unless @can_be_exported.nil?
        @can_be_exported = (self.valid? and !ExportChannels.format(channel).blank?)
        ExportChannels.validators(channel).each do |v|
          self.send(v)
        end
        @can_be_exported &&= (export_errors.size == 0)
        @can_be_exported
      end

      def sending_info(channel_name=nil)
        channel_name ||= self.client.invoice_format rescue nil
        channel = ExportChannels.available[channel_name.to_s]
        format = nil
        recipients = nil
        if channel
          format = channel["locales"][I18n.locale.to_s]
          if channel.has_key?("validators") and channel["validators"].to_a.include? "Haltr::Validator::Mail"
            recipients = "\n#{self.recipient_emails.join("\n")}"
          end
        else
          format = "Can't find channel #{channel_name}, please check channels.yml"
        end
        if channel["format"] == "pdf" and self.client and self.client.language != User.current.language
          lang=" (#{l(:general_lang_name, :locale=>self.client.language)})"
        end
        "#{format}#{lang}<br/>#{parsed_errors}<br/>#{recipients}".html_safe
      end

      def parsed_errors
        errors = ""
        errors += export_errors.collect {|e|
          e.is_a?(Array) ? e.collect {|e2|
            if e2.is_a?(Array)
              l(*e2)
            else
              l(e2, default: e2)
            end
          }.join(" ") : l(e, default: e)
        }.join(", ") if export_errors and export_errors.size > 0
        errors += self.errors.full_messages.join(", ")
        errors
      end

      # errors to be raised on sending invoice
      def add_export_error(err)
        @export_errors ||= []
        @export_errors << err
      end

    end
  end

end

