require 'telegram/bot'

require 'dotenv'
Dotenv.load

token = ENV['TELEGRAM_TOKEN']

class EventManager
  def initialize
    @votes = {}
    @limits = {}
    @names = {}
    @states = {}
  end

  def setup(name, limit, chat_id)
    @names[chat_id] = name
    @limits[chat_id] = limit.to_i
    @states[chat_id] = true
    @votes[chat_id] = {}
  end

  def value(chat_id)
    votes(chat_id).keys.count || 0
  end

  def status(chat_id, full = false)
    message = "Event: #{name(chat_id)}, limit: #{limit(chat_id)}, available: #{limit(chat_id)- value(chat_id)}"

    if full || !started(chat_id)
      idx = 0
      members = (votes(chat_id).values || []).each do |name|
        idx = idx + 1
        "#{idx.to_s}. #{name}"
      end
      "#{message}\nMembers:\n#{members.join("\n")}"
    end
  end

  def inc(chat_id, user)
    return unless started(chat_id)
    @votes[chat_id] ||= {}
    @votes[chat_id][user.id] = get_label(user)
    stop(chat_id) if limit(chat_id) == value(chat_id)
  end

  def dec(chat_id, user)
    votes(chat_id).delete(user.id)
    start(chat_id) if limit(chat_id) != value(chat_id)
  end

  private

  def votes(chat_id)
    @votes[chat_id] || {}
  end

  def start(chat_id)
    @states[chat_id] = true
  end

  def stop(chat_id)
    @states[chat_id] = false
  end

  def limit(chat_id)
    @limits[chat_id]
  end

  def started(chat_id)
    @states[chat_id]
  end

  def name(chat_id)
    @names[chat_id]
  end

  def get_label(user)
    user.username || [user.first_name, user.last_name].compact.join(' ')
  end
end

Telegram::Bot::Client.run(token) do |bot|
  @event_manager = EventManager.new
  bot.listen do |message|
    begin
      case message.text
        when /\/event\s*(\S*)\s*(\S*)/
          name = $1
          limit = $2
          if limit.empty?
            response = 'Example: /event Hockey 10'
          else
            @event_manager.setup(name, limit, message.chat.id)
            response = @event_manager.status(message.chat.id)
          end
          bot.api.sendMessage(chat_id: message.chat.id, text: response)
        when '/status'
          bot.api.sendMessage(chat_id: message.chat.id, text: @event_manager.status(message.chat.id, true))
        when '+'
          @event_manager.inc(message.chat.id, message.from)
          bot.api.sendMessage(chat_id: message.chat.id, text: @event_manager.status(message.chat.id))
        when '-'
          @event_manager.dec(message.chat.id, message.from)
          bot.api.sendMessage(chat_id: message.chat.id, text: @event_manager.status(message.chat.id))
      end
    rescue Exception => e
      puts e.message
      puts e.backtrace.inspect
    end
  end
end