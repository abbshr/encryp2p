require "json"

class Encp

  HEADEND = "HEADEND\r\n"
  DATAEND = "DATAEND\r\n"

  def generate json_head, data=''
    "#{JSON.generate json_head}\n#{HEADEND}#{data}\n#{DATAEND}"
  end

  def parse socket
    @err = :none

    head = head_parser socket
    data = data_parser socket
    
    [head, data, @err]
  end

  private
  def parser src, endup, err_res
    res = ''
    until endup == (chunk = src.gets)
      if chunk.nil?
        @err = :closed
        res = err_res if head.size == 0
        break
      end
      res += chunk
    end
    res
  end

  def head_parser src
    # parse the json head
    head = parser src, HEADEND, '{}'
    
    begin
      head = JSON.parse head, :symbolize_names => true
    rescue Exception => e
      head = {}
      @err = :parse_error
    end

    head
  end

  def data_parser src
    #get the binary data
    parser(src, DATAEND, '').chomp
  end
end