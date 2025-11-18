using System.Data;
using System.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace SimpleSmartMail.Data.Common;

public abstract class BaseRepository
{
    private readonly string _connectionString;

    protected BaseRepository(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new ArgumentNullException("Connection string 'DefaultConnection' not found");
    }

    protected SqlConnection CreateConnection()
    {
        return new SqlConnection(_connectionString);
    }

    protected async Task<T?> ExecuteScalarAsync<T>(string storedProcedure, SqlParameter[]? parameters = null)
    {
        using var connection = CreateConnection();
        using var command = new SqlCommand(storedProcedure, connection)
        {
            CommandType = CommandType.StoredProcedure
        };

        if (parameters != null)
        {
            command.Parameters.AddRange(parameters);
        }

        await connection.OpenAsync();
        var result = await command.ExecuteScalarAsync();

        return result != null && result != DBNull.Value ? (T)result : default;
    }

    protected async Task<int> ExecuteNonQueryAsync(string storedProcedure, SqlParameter[]? parameters = null)
    {
        using var connection = CreateConnection();
        using var command = new SqlCommand(storedProcedure, connection)
        {
            CommandType = CommandType.StoredProcedure
        };

        if (parameters != null)
        {
            command.Parameters.AddRange(parameters);
        }

        await connection.OpenAsync();
        return await command.ExecuteNonQueryAsync();
    }
}
