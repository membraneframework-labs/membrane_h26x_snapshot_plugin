defmodule Membrane.H26x.Snapshot.Tee do
  use Membrane.Bin

  alias Membrane.H26x.Snapshot.KFrameFilter
  alias Membrane.H26x.Snapshot.ImageSink

  def_options capture_path: [
                spec: Path.t(),
                description: "Path to directory where captures should be stored"
              ],
              encoding: [
                spec: :H264 | :H265,
                description: """
                Encoding type determining which decoder will be used for the given stream.
                """
              ],
              timeout: [
                spec: integer(),
                description: "Describes when first capture should be taken after stream starts. If 0, capture will be taken from first K-frame. Defaults to 0",
                default: 0
              ],
              interval: [
                spec: integer(),
                description: "Describes how often capture should be taken. If 0, capture will be taken only once. Defaults to 0",
                default: 0
              ],
              time_unit: [
                spec: :hour | :minute | :second,
                description: "Timeunit to use with 'timeout' and 'interval' settings. Defaults to :second",
                default: :second
              ]

  def_input_pad :input,
    availability: :always,
    accepted_format: any_of(
      Membrane.H264,
      Membrane.H265
    )

  def_output_pad :output,
    availability: :always,
    accepted_format: any_of(
      Membrane.H264,
      Membrane.H265
    )

  @impl true
  def handle_init(_ctx, opts) do
    state = Map.merge(%{timeout: 0, interval: 0, time_unit: :second}, opts)
    spec = [
      bin_input(:input)
      |> child(:tee, Membrane.Tee.Master)
      |> via_out(:master)
      |> bin_output(:output),
      get_child(:tee)
      |> via_out(:copy)
      |> child(
        :k_frame_filter,
        %KFrameFilter{
          encoding: state.encoding,
          timeout: state.timeout,
          interval: state.interval,
          time_unit: state.time_unit
        }
      )
      |> child(:parser, get_parser(state.encoding))
      |> child(:decoder, get_decoder(state.encoding))
      |> child(:image_sink, %ImageSink{capture_path: state.capture_path})
    ]

    {[spec: spec], state}
  end

  def handle_child_notification(:capture_finished, :kframe_filter, _ctx, state) do
    {[remove_children: [:kframe_filter, :parser, :decoder, :image_sink]], state}
  end

  defp get_parser(:H264), do: Membrane.H264.Parser
  defp get_parser(:H265), do: Membrane.H265.Parser
  defp get_parser(encoding), do: raise "Unexpected encoding: #{encoding}"

  defp get_decoder(:H264), do: Membrane.H264.FFmpeg.Decoder
  defp get_decoder(:H265), do: Membrane.H265.FFmpeg.Decoder
  defp get_decoder(encoding), do: raise "Unexpected encoding: #{encoding}"
end
