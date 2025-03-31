defmodule Membrane.H26x.Snapshot.ImageSink do
  use Membrane.Sink

  require Logger

  def_options capture_path: [
                spec: Path.t(),
                description: "Path to directory where captures should be stored"
              ]

  def_input_pad :input, flow_control: :auto, accepted_format: _any

  @impl true
  def handle_init(_ctx, opts) do
    {[], opts}
  end

  @impl true
  def handle_buffer(:input, buffer, %{pads: %{input: %{stream_format: stream_format}}}, state) do
    with {:ok, encoding, width, height} <- parse_stream_format(stream_format),
          {:ok, decoded} <- Image.YUV.decode(buffer.payload, width, height, encoding),
          {:ok, image} <- Image.YUV.to_rgb(decoded, width, height, encoding, :bt601) do
      Image.write(image, "#{state.capture_path}.png")
    else
      {:error, msg} -> Logger.error(msg)

    end
    {[], state}
  end

  defp parse_stream_format(stream_format) do
    case stream_format.pixel_format do
      :I420 -> {:ok, :C420, stream_format.width, stream_format.height}
      :I422 -> {:ok, :C422, stream_format.width, stream_format.height}
      :I444 -> {:ok, :C444, stream_format.width, stream_format.height}
      other-> {:error, "Unsupported pixel format: #{other}"}
    end
  end
end
