import 'package:supabase_flutter/supabase_flutter.dart';

String buildingErrorMessage(Object error) {
  if (error is StateError) return error.message.toString();
  if (error is PostgrestException) {
    return switch (error.message) {
      'ACCESS_DENIED' =>
        'אין הרשאה לפעולה הזאת. יש לבדוק שהחשבון וההרשאות מעודכנים.',
      'ALREADY_APPLIED' => 'כבר קיימת חברות או בקשה לבניין הזה.',
      'LEGAL_NOT_ACCEPTED' => 'יש לאשר את תנאי השימוש לפני ההמשך.',
      'RATE_LIMITED' => 'בוצעו יותר מדי ניסיונות. אפשר לנסות שוב מאוחר יותר.',
      'POST_CLOSED' => 'הפרסום נסגר לתגובות.',
      'LAST_BUILDING_ADMIN' =>
        'מנהל הבניין האחרון צריך למנות מחליף או לארכב את הבניין לפני היציאה.',
      'PHONE_INVALID' =>
        'יש להזין מספר נייד ישראלי תקין, או להשאיר את השדה ריק.',
      'PHONE_TAKEN' => 'מספר הטלפון כבר משויך לחשבון אחר.',
      'BUILDING_NEEDS_ADMIN' => 'נדרש מנהל בניין מאושר לפני שחזור הבניין.',
      'INVALID_ARGUMENT' => 'יש לבדוק את הפרטים שהזנת.',
      'INVALID_STATE' => 'הבקשה כבר השתנתה. נסה לרענן.',
      _ =>
        error.code == '23505'
            ? 'כבר קיים בניין עם הכתובת והשם האלה.'
            : 'לא הצלחנו להשלים את הפעולה. אפשר לנסות שוב.',
    };
  }
  return 'לא הצלחנו להתחבר כרגע. בדוק את החיבור ונסה שוב.';
}
