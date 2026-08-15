#include "nudge/protocol_json.h"

#include <iomanip>
#include <sstream>

namespace nudge {
namespace {

std::string escaped(const std::string& input) {
  std::ostringstream output;
  for (const unsigned char character : input) {
    switch (character) {
      case '"':
        output << "\\\"";
        break;
      case '\\':
        output << "\\\\";
        break;
      case '\b':
        output << "\\b";
        break;
      case '\f':
        output << "\\f";
        break;
      case '\n':
        output << "\\n";
        break;
      case '\r':
        output << "\\r";
        break;
      case '\t':
        output << "\\t";
        break;
      default:
        if (character < 0x20) {
          output << "\\u" << std::hex << std::setw(4) << std::setfill('0')
                 << static_cast<int>(character) << std::dec;
        } else {
          output << character;
        }
    }
  }
  return output.str();
}

}  // namespace

std::string encode_activity_event(const ActivityEvent& event) {
  std::ostringstream output;
  output << std::setprecision(10) << '{'
         << "\"protocolVersion\":" << event.protocol_version << ','
         << "\"messageType\":\"activity_event\"," 
         << "\"eventId\":\"" << escaped(event.event_id) << "\"," 
         << "\"sourceRecordId\":\"" << escaped(event.source_record_id)
         << "\"," 
         << "\"deviceId\":\"" << escaped(event.device_id) << "\"," 
         << "\"sessionId\":\"" << escaped(event.session_id) << "\",";
  if (!event.activity_correlation_id.empty()) {
    output << "\"activityCorrelationId\":\""
           << escaped(event.activity_correlation_id) << "\",";
  }
  output << "\"sequence\":" << event.sequence << ','
         << "\"activityType\":\"focus\"," 
         << "\"eventType\":\"" << event_type_name(event.event_type)
         << "\"," 
         << "\"metricValue\":" << event.metric_minutes << ','
         << "\"metricUnit\":\"minutes\"," 
         << "\"occurredAtEpochMs\":" << event.occurred_at_epoch_ms << '}';
  return output.str();
}

}  // namespace nudge
