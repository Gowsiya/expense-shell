USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

mkdir -p /var/log/expense-logs

LOGS_FOLDER="/var/log/expense-logs"
LOG_FILE=$(echo $0 | cut -d "." -f1)
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
LOG_FILE_NAME="$LOGS_FOLDER/$LOG_FILE-$TIMESTAMP.log"

echo "Script started executing at : $TIMESTAMP" &>>LOG_FILE_NAME

if [ $USERID -ne 0 ]
then
    echo "ERROR: User must have root access to execute this command"
    exit 1
fi

VALIDATE () {
    if [ $1 -ne 0 ]
    then
        echo -e "$2 ... $R Failure $N"
        exit 1
    else 
        echo -e "$2 ... $G Success $N"
    fi

}

dnf module disable nodejs -y &>>LOG_FILE_NAME
VALIDATE $? "Disabling default nodejs version"

dnf module enable nodejs:20 -y &>>LOG_FILE_NAME
VALIDATE $? "Enabling the required nodejs version"

dnf install nodejs -y &>>LOG_FILE_NAME 
VALIDATE $? "Installing nodejs"

id expense &>>LOG_FILE_NAME
if [ $? -ne 0 ]
then
    useradd expense
    echo "Adding expense user"
else
    echo "User expense already exists"
fi

mkdir -p /app
VALIDATE $? "Creating app directiory"

curl -o /tmp/backend.zip https://expense-builds.s3.us-east-1.amazonaws.com/expense-backend-v2.zip &>>LOG_FILE_NAME
VALIDATE $? "Downloading the application"

cd /app
rm -rf *

unzip /tmp/backend.zip &>>LOG_FILE_NAME

npm install &>>LOG_FILE_NAME
VALIDATE $? "Installing dependencies"

cp /home/ec2-user/expense-shell/backend.service /etc/systemd/system/backend.service

#Prepare Mysql Schema

dnf install mysql -y &>>LOG_FILE_NAME
VALIDATE $? "Installing mysql Client"

mysql -h  -uroot mysql.gsdevops.online -pExpenseApp@1 < /app/schema/backend.sql &>>LOG_FILE_NAME
VALIDATE $? "Loading Mysql Schema"

systemctl daemon-reload &>>LOG_FILE_NAME
VALIDATE $? "Daemon reload"

systemctl enable backend &>>LOG_FILE_NAME
VALIDATE $? "Enabling backend Service"

systemctl restart backend &>>LOG_FILE_NAME
VALIDATE $? "starting backend Service"
