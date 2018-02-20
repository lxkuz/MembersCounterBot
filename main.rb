require 'telegram/bot'

require 'dotenv'
Dotenv.load

token = ENV['TELEGRAM_TOKEN']

class EventManager
  def setup(name, limit)
    @name = name
    @limit = limit.to_i
    @votes = {}
    @started = true
  end

  def value
    @votes.keys.count
  end

  def status
    if @started
      "Event: #{@name}, limit: #{@limit}, available: #{@limit - value}"
    else
      index = 0
      "Event: #{@name} \n" +
        "Members: \n" + @votes.values.each do |name|
          index += 1
          "#{index}) #{name}"
      end.join("\n")
    end
  end

  def inc(user)
    return unless @started
    @votes[user.id] = get_label(user)
    stop() if @limit == value
  end

  def dec(user)
    @votes.delete(user.id)
    start() if @limit != value
  end

  def start
    @started = true
  end

  def stop
    @started = false
  end

  private

  def get_label(user)
    user.username || [user.first_name, user.last_name].compact.join(' ')
  end
end

Telegram::Bot::Client.run(token) do |bot|
  @event_manager = EventManager.new
  bot.listen do |message|
    case message.text
      when /\/event\s*(\S*)\s*(\S*)/
        name = $1
        limit = $2
        @event_manager.setup(name, limit)
        bot.api.sendMessage(chat_id: message.chat.id, text: @event_manager.status())
      when '/status'
        bot.api.sendMessage(chat_id: message.chat.id, text: @event_manager.status())
      when '+'
        @event_manager.inc(message.from)
        bot.api.sendMessage(chat_id: message.chat.id, text: @event_manager.status())
      when '-'
        @event_manager.dec(message.from)
        bot.api.sendMessage(chat_id: message.chat.id, text: @event_manager.status())
    end
  end
end