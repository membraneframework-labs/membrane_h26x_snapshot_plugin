defmodule Membrane.H26x.Snapshot.KFrameFilter do
  use Membrane.Filter

  def_options timeout: [
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
              ],
              encoding: [
                spec: :H264 | :H265,
                description: "Encoding type determining which decoder will be used for the given stream."
              ]

  def_input_pad :input,
    availability: :always,
    accepted_format: any_of(
      Membrane.H264,
      Membrane.H265
    ),
    flow_control: :auto

  def_output_pad :output,
    availability: :always,
    accepted_format: any_of(
      Membrane.H264,
      Membrane.H265
    ),
    flow_control: :auto

  @impl true
  def handle_init(_ctx, opts) do
    opts = Map.merge(%{timeout: 0, interval: 0, time_unit: :second}, opts)
    {[], Map.merge(opts, %{next_take: DateTime.add(DateTime.utc_now(), opts.timeout, opts.time_unit)})}
  end

  @impl true
  def handle_buffer(:input, %Membrane.Buffer{metadata: metadata} = buffer, ctx, state) do
    if metadata[metadata_key(state.encoding)].key_frame? do
      now = DateTime.utc_now()
      if DateTime.compare(now, state.next_take) == :gt do
        if state.interval == 0 do
          {[forward: buffer, notify_parent: :capture_finished], state}
        else
          {[forward: buffer], %{state | next_take: DateTime.add(now, state.interval, state.time_unit)}}
        end
      else
        {[], state}
      end
    else
      {[], state}
    end
  end

  defp metadata_key(:H264), do: :h264
  defp metadata_key(:H265), do: :h265
  defp metadata_key(encoding), do: raise "Unexpected encoding: #{encoding}"

end
