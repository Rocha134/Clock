defmodule WatchWeb.IndigloManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {:ok, %{ui_pid: ui, st: IndigloOff, counter: 0}}
  end

  def handle_info(:"top-right", %{ui_pid: ui, st: IndigloOff} = state) do
    GenServer.cast(ui, :set_indiglo)
    {:noreply, state |> Map.put(:st, IndigloOn)}
  end

  def handle_info(:"top-right", %{st: IndigloOn} = state) do
    Process.send_after(self(), :waiting_indiglooff, 2000)
    {:noreply, state |> Map.put(:st, Waiting)}
  end

  def handle_info(:waiting_indiglooff, %{ui_pid: ui, st: Waiting} = state) do
    GenServer.cast(ui, :unset_indiglo)
    {:noreply, state |> Map.put(:st, IndigloOff)}
  end

  # ------------- IndigloOff -------------
  def handle_info(:start_alarm, %{st: IndigloOff, ui_pid: ui} = state) do
    GenServer.cast(ui, :set_indiglo)
    Process.send_after(self(), :OnStateTrans, 0)
    {:noreply, %{state | st: AlarmOn}}
  end

  def handle_info(:OnStateTrans, %{st: AlarmOn, ui_pid: ui, counter: counter} = state) do
    GenServer.cast(ui, :set_indiglo)
    if (counter < 5) do
      if counter > 0 do
        counter = counter + 1
        Process.send_after(self(), :OffStateTrans, 1000)
        {:noreply, state |> Map.put(:st, AlarmOff) |> Map.put(:counter, counter)}
      else
        Process.send_after(self(), :OffStateTrans, 1000)
        {:noreply, state |> Map.put(:st, AlarmOff) |> Map.put(:counter, counter)}
      end
    end
  end

  def handle_info(:OffStateTrans, %{st: AlarmOff, ui_pid: ui, counter: counter} = state) do
    GenServer.cast(ui, :unset_indiglo)
    counter = counter + 1
    if (counter < 5) do
      Process.send_after(self(), :OnStateTrans, 1000)
      {:noreply, state |> Map.put(:st, AlarmOn) |> Map.put(:counter, counter)}
    else
      GenServer.cast(ui, :unset_indiglo)
      {:noreply, state |> Map.put(:st, IndigloOff)}
    end
  end

  def handle_info(:resume_clock, %{counter: counter, st: st, ui_pid: ui} = state) do
    {:noreply, state}
  end
  def handle_info(:"bottom-right", %{counter: counter, st: st, ui_pid: ui} = state) do
    {:noreply, state}
  end
  def handle_info(:"top-left", %{counter: counter, st: st, ui_pid: ui} = state) do
    {:noreply, state}
  end
  def handle_info(:"top-right", %{counter: counter, st: st, ui_pid: ui} = state) do
    {:noreply, state}
  end
  def handle_info(:"bottom-left", %{counter: counter, st: st, ui_pid: ui} = state) do
    {:noreply, state}
  end
end
