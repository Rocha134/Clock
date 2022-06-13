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
       alarm: ~T[00:00:00],
       st2: ModeCtrl,
       st3: Idle,
       selection: Hour,
       show: false,
       count: 0,
     }}
  end
  # ------------------------------------------
  # ------------- Actualización de tiempo -------------
  def handle_info(:working_working, %{ui_pid: ui, time: time, alarm: alarm, st: current, mode: mode} = state) do
    Process.send_after(self(), :working_working, 1000)
    if (mode == Time and current == Working) do
      time = Time.add(time, 1)
      GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string()})
      if time |> Time.truncate(:second) == alarm |> Time.truncate(:second) do
        :gproc.send({:p, :l, :ui_event}, :start_alarm)
      end
      {:noreply, state |> Map.put(:time, time)}
    else
      if (mode == TEditing) do
        {:noreply, state |> Map.put(:time, time)}
      else
        time = Time.add(time, 1)
        {:noreply, state |> Map.put(:time, time)}
      end
      #GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string()})
    end
  end
  # ---------------------------------------------------

  # ------------- Manejo de stopwatch (actualización en segundo plano del reloj) ------------
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
    {:noreply, state |> Map.put(:st3, Waiting)}
  end

  def handle_info(:"bottom-right", %{mode: Time, st3: Waiting} = state) do
    # Process.send_after(self(), :start_timer, 0)
    {:noreply, state |> Map.put(:st3, Idle)}
  end

  def handle_info(:waiting_editing, %{st3: Waiting} = state) do
    Process.send_after(self(), :stop_clock, 250)
    Process.send_after(self(), :editing_editing, 250)
    {:noreply, state |> Map.put(:st3, Editing) |> Map.put(:selection, Hour) |> Map.put(:count, 0) |> Map.put(:show, true)}
  end

  def handle_info(:"bottom-right", %{st3: Editing, count: count, show: show, selection: selection, ui_pid: ui, time: time} = state) do
    count = 0
    show = true
    selection = change_selection(selection)
    format(show, time, selection, ui)
    {:noreply, state |> Map.put(:count, count) |> Map.put(:show, show) |> Map.put(:selection, selection)}
  end

  def handle_info(:"bottom-left", %{st3: Editing, count: count, show: show, selection: selection, time: time} = state) do
    count = 0
    show = true
    time = increase_selection(selection, time)
    {:noreply, state |> Map.put(:time, time) |> Map.put(:count, count) |> Map.put(:show, show)}
  end
  # ---------------------------------------------

  def handle_info(:editing_editing, %{count: count, show: show, st3: Editing, ui_pid: ui, time: time, selection: selection} = state) do
    count = count + 1
    if (count < 20) do
      Process.send_after(self(), :editing_editing, 250)
      show = !show
      format(show, time, selection, ui)
      {:noreply, state |> Map.put(:count, count) |> Map.put(:show, show)}
    else
      :gproc.send({:p, :l, :ui_event}, :resume_clock)
      {:noreply, state |> Map.put(:st3, Idle)}
    end
  end

  def handle_info(:stop_clock, %{st: Working} = state) do
    {:noreply, state |> Map.put(:mode, TEditing) |> Map.put(:st, Stopped)}
  end

  def handle_info(:resume_clock, %{st: Stopped, time: time, ui_pid: ui} = state) do
    # GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string()})
    {:noreply, state |> Map.put(:mode, Time) |> Map.put(:st, Working)}
  end

  # -------------------------Alarm-manager------------
  def handle_info(:"bottom-left", %{mode: Time, st3: Idle} = state) do
    Process.send_after(self(), :alarm_waiting_editing, 250)
    {:noreply, state |> Map.put(:st3, A_waiting)}
  end

  def handle_info(:"bottom-left", %{mode: Time, st3: A_waiting} = state) do
    # Process.send_after(self(), :start_timer, 0)
    {:noreply, state |> Map.put(:st3, Idle)}
  end

  def handle_info(:alarm_waiting_editing, %{st3: A_waiting} = state) do
    Process.send_after(self(), :A_editing_editing, 250)
    Process.send_after(self(), :A_stop_clock, 250)
    {:noreply, state |> Map.put(:st3, A_editing) |> Map.put(:selection, Hour) |> Map.put(:count, 0) |> Map.put(:show, true)}
  end

  def handle_info(:"bottom-right", %{st3: A_editing, count: count, show: show, selection: selection, ui_pid: ui, alarm: alarm} = state) do
    count = 0
    show = true
    selection = change_selection(selection)
    format(show, alarm, selection, ui)
    {:noreply, state |> Map.put(:count, count) |> Map.put(:show, show) |> Map.put(:selection, selection)}
  end

  def handle_info(:"bottom-left", %{st3: A_editing, count: count, show: show, selection: selection, alarm: alarm} = state) do
    count = 0
    show = true
    alarm = increase_selection(selection, alarm)
    {:noreply, state |> Map.put(:alarm, alarm) |> Map.put(:count, count) |> Map.put(:show, show)}
  end
  # ---------------------------------------------

  def handle_info(:A_editing_editing, %{count: count, show: show, st3: A_editing, ui_pid: ui, alarm: alarm, selection: selection} = state) do
    count = count + 1
    if (count < 20) do
      Process.send_after(self(), :A_editing_editing, 250)
      show = !show
      format(show, alarm, selection, ui)
      {:noreply, state |> Map.put(:count, count) |> Map.put(:show, show)}
    else
      :gproc.send({:p, :l, :ui_event}, :resume_clock)
      {:noreply, state |> Map.put(:st3, Idle)}
    end
  end

  def handle_info(:A_stop_clock, %{st: Working} = state) do
    {:noreply, state |> Map.put(:mode, TAediting) |> Map.put(:st, Stopped)}
  end

  #------------------catcher------------------
  def handle_info(:"top-right", %{alarm: alarm, count: count, mode: mode, selection: selection, show: show, st: st, st2: st2, st3: st3, time: time, ui_pid: ui} = state) do
    {:noreply, state}
  end
  def handle_info(:"bottom-right", %{alarm: alarm, count: count, mode: mode, selection: selection, show: show, st: st, st2: st2, st3: st3, time: time, ui_pid: ui} = state) do
    {:noreply, state}
  end
  def handle_info(:"bottom-left", %{alarm: alarm, count: count, mode: mode, selection: selection, show: show, st: st, st2: st2, st3: st3, time: time, ui_pid: ui} = state) do
    {:noreply, state}
  end
  def handle_info(:"top-left", %{alarm: alarm, count: count, mode: mode, selection: selection, show: show, st: st, st2: st2, st3: st3, time: time, ui_pid: ui} = state) do
    {:noreply, state}
  end
  def handle_info(:resume_clock, %{alarm: alarm, count: count, mode: mode, selection: selection, show: show, st: st, st2: st2, st3: st3, time: time, ui_pid: ui} = state) do
    {:noreply, state}
  end
  #def handle_info(_event, state), do: {:noreply, state}


  # ------------- Funciones -------------
  def increase_selection(selection, time) do
    case(selection) do
      Hour -> Time.add(time, 3600)
      Minute -> Time.add(time, 60)
      _ -> Time.add(time, 1)
    end
  end

  def change_selection(selection) do
    case selection do
      Hour -> Minute
      Minute -> Second
      _ -> Hour
    end
  end

  def format(show, time, selection, ui) do
    if (show) do
      GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string()})
    else
      case selection do
        Hour ->  GenServer.cast(ui, {:set_time_display, "  " <> String.slice(Time.truncate(time, :second) |> Time.to_string(), 2, 8)})
        Minute ->  GenServer.cast(ui, {:set_time_display, String.slice(Time.truncate(time, :second) |> Time.to_string(), 0, 3) <> "  " <> String.slice(Time.truncate(time, :second) |> Time.to_string(), 5, 8)})
        _ ->  GenServer.cast(ui, {:set_time_display, String.slice(Time.truncate(time, :second) |> Time.to_string(), 0, 6) <> "  "})
      end
    end
  end
  #--------------------------------------

end
