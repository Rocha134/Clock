defmodule WatchWeb.ClockManager do
  use GenServer

  # ------------- Inicialización -------------
  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {_, now} = :calendar.local_time()

    Process.send_after(self(), :working_working, 1000)

    {:ok,
     %{
       ui_pid: ui,
       time: Time.from_erl!(now),
       st: Working,
       mode: Time,
       alarm: Time.from_erl!(now) |> Time.add(3),
       st2: ModeCtrl,
       st3: Idle,
       selection: None,
       show: false,
       count: 0,
       countE: 0,
       timerEnabled: false
     }}
  end

  # ------------------------------------------

  # ------------- Actualización de tiempo -------------
  def handle_info(:working_working, %{ui_pid: ui, time: time, alarm: alarm, st: Working, mode: mode} = state) do
    Process.send_after(self(), :working_working, 1000)
    time = Time.add(time, 1)

    if mode == Time do
      GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string()})
    end

    if time == alarm do
      :gproc.send({:p, :l, :ui_event}, :start_alarm)
    end

    {:noreply, state |> Map.put(:time, time)}
  end
  # ---------------------------------------------------

  # ------------- Manejo de stopwatch (actualización en segundo plano del reloj) -------------
  def handle_info(:"top-left", %{ui_pid: ui, st2: ModeCtrl, mode: SWatch, time: time} = state) do
    GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string()})
    {:noreply, %{state | mode: Time}}
  end

  def handle_info(:"top-left", %{st2: ModeCtrl, mode: Time} = state) do
    {:noreply, %{state | mode: SWatch}}
  end
  # ------------------------------------------------------------------------------------------

  # ------------- Edición del reloj -------------
  def handle_info(:"bottom-right", %{mode: Time, st3: Idle} = state) do
    Process.send_after(self(), :waiting_editing, 250)
    IO.inspect("Moving idle to waiting")
    {:noreply, state |> Map.put(:st3, Waiting)}
  end

  def handle_info(:"bottom-right", %{mode: Time, st3: Waiting} = state) do
    IO.inspect("Moving waiting to idle")
    # Process.send_after(self(), :start_timer, 0)
    {:noreply, state |> Map.put(:st3, Idle)}
  end

  def handle_info(:waiting_editing, %{st3: Waiting} = state) do
    IO.inspect("Moving waiting to editing")
    # Process.send_after(self(), :start_timer, 0)

    {:noreply, state |> Map.put(:st3, Editing)}
  end
  # ---------------------------------------------

  def handle_info(_event, state), do: {:noreply, state}
end
