defmodule Money.ExchangeRates.Cache do
  require Logger

  @ets_table :exchange_rates

  def init do
    if :ets.info(@ets_table) == :undefined do
      :ets.new(@ets_table, [
        :named_table,
        :public,
        read_concurrency: true
      ])
    else
      @ets_table
    end
  end

  def latest_rates do
    try do
      case :ets.lookup(@ets_table, :latest_rates) do
        [{:latest_rates, rates}] -> {:ok, rates}
        [] -> {:error, {Money.ExchangeRateError, "No exchange rates were found"}}
      end
    rescue
      ArgumentError ->
        Logger.error("Argument error getting exchange rates from ETS table")
        {:error, {Money.ExchangeRateError, "No exchange rates are available"}}
    end
  end

  def historic_rates(%Date{calendar: Calendar.ISO} = date) do
    try do
      case :ets.lookup(@ets_table, date) do
        [{_date, rates}] ->
          {:ok, rates}

        [] ->
          {:error,
           {Money.ExchangeRateError, "No exchange rates for #{Date.to_string(date)} were found"}}
      end
    rescue
      ArgumentError ->
        Logger.error("Argument error getting historic exchange rates from ETS table")

        {:error,
         {Money.ExchangeRateError, "No exchange rates for #{Date.to_string(date)} are available"}}
    end
  end

  def historic_rates(%{year: year, month: month, day: day}) do
    {:ok, date} = Date.new(year, month, day)
    historic_rates(date)
  end

  def last_updated do
    case :ets.lookup(@ets_table, :last_updated) do
      [{:last_updated, timestamp}] ->
        {:ok, timestamp}

      [] ->
        Logger.error("Argument error getting last updated timestamp from ETS table")
        {:error, {Money.ExchangeRateError, "Last updated date is not known"}}
    end
  end

  def store_latest_rates(rates, retrieved_at) do
    :ets.insert(@ets_table, {:latest_rates, rates})
    :ets.insert(@ets_table, {:last_updated, retrieved_at})
  rescue
    ArgumentError ->
      Logger.error("Failed to store latest rates")
  end

  def store_historic_rates(rates, date) do
    :ets.insert(@ets_table, {date, rates})
  rescue
    ArgumentError ->
      Logger.error("Failed to store historic rates for #{inspect(date)}")
  end

  def get(key) do
    case :ets.lookup(@ets_table, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  def put(key, value) do
    :ets.insert(@ets_table, {key, value})
  end
end
